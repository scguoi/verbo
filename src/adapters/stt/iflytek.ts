import type { STTAdapter, STTOptions } from './types'

export interface IFlytekConfig {
  readonly appId: string
  readonly apiKey: string
  readonly apiSecret: string
}

const IFLYTEK_HOST = 'iat-api.xfyun.cn'
const IFLYTEK_PATH = '/v2/iat'

const LANGUAGE_MAP: Record<string, string> = {
  zh: 'cn_mandarin',
  en: 'en_us',
}

const DEFAULT_LANGUAGE = 'cn_mandarin'

export function mapLanguage(lang: string): string {
  return LANGUAGE_MAP[lang] ?? DEFAULT_LANGUAGE
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function parseIFlytekResponse(response: any): string {
  const ws = response?.data?.result?.ws
  if (!Array.isArray(ws)) {
    return ''
  }
  return ws
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    .flatMap((item: any) => item.cw ?? [])
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    .map((cw: any) => cw.w ?? '')
    .join('')
}

async function hmacSha256(key: string, message: string): Promise<string> {
  const encoder = new TextEncoder()
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    encoder.encode(key),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign('HMAC', cryptoKey, encoder.encode(message))
  return btoa(String.fromCharCode(...new Uint8Array(signature)))
}

export async function buildAuthUrl(config: IFlytekConfig): Promise<string> {
  const date = new Date().toUTCString()
  const signatureOrigin = `host: ${IFLYTEK_HOST}\ndate: ${date}\nGET ${IFLYTEK_PATH} HTTP/1.1`
  const signature = await hmacSha256(config.apiSecret, signatureOrigin)

  const authorizationOrigin =
    `api_key="${config.apiKey}", algorithm="hmac-sha256", ` +
    `headers="host date request-line", signature="${signature}"`
  const authorization = btoa(authorizationOrigin)

  const params = new URLSearchParams({
    authorization,
    date,
    host: IFLYTEK_HOST,
  })

  return `wss://${IFLYTEK_HOST}${IFLYTEK_PATH}?${params.toString()}`
}

function buildFirstFrame(
  config: IFlytekConfig,
  lang: string,
  audioBase64: string,
  status: number,
): string {
  return JSON.stringify({
    common: { app_id: config.appId },
    business: {
      language: mapLanguage(lang),
      domain: 'iat',
      accent: mapLanguage(lang),
      vad_eos: 3000,
      dwa: 'wpgs',
    },
    data: {
      status,
      format: 'audio/L16;rate=16000',
      encoding: 'raw',
      audio: audioBase64,
    },
  })
}

function buildContinueFrame(audioBase64: string, status: number): string {
  return JSON.stringify({
    data: {
      status,
      format: 'audio/L16;rate=16000',
      encoding: 'raw',
      audio: audioBase64,
    },
  })
}

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  return btoa(String.fromCharCode(...new Uint8Array(buffer)))
}

const FRAME_SIZE = 1280

function splitIntoFrames(buffer: ArrayBuffer): readonly ArrayBuffer[] {
  const frames: ArrayBuffer[] = []
  const view = new Uint8Array(buffer)
  for (let offset = 0; offset < view.byteLength; offset += FRAME_SIZE) {
    frames.push(view.slice(offset, offset + FRAME_SIZE).buffer)
  }
  return frames
}

function openWebSocket(
  url: string,
  config: IFlytekConfig,
  lang: string,
  frames: readonly ArrayBuffer[],
  onResult: (text: string, isLast: boolean) => void,
  onError: (error: Error) => void,
  onComplete: () => void,
): void {
  const ws = new WebSocket(url)
  let frameIndex = 0

  ws.onopen = () => {
    if (frames.length === 0) {
      ws.send(buildFirstFrame(config, lang, '', 2))
      return
    }
    const firstAudio = arrayBufferToBase64(frames[0])
    const status = frames.length === 1 ? 2 : 0
    ws.send(buildFirstFrame(config, lang, firstAudio, status))
    frameIndex = 1

    const sendNextFrame = () => {
      if (frameIndex >= frames.length) return
      const isLast = frameIndex === frames.length - 1
      const audio = arrayBufferToBase64(frames[frameIndex])
      ws.send(buildContinueFrame(audio, isLast ? 2 : 1))
      frameIndex++
      if (!isLast) {
        setTimeout(sendNextFrame, 40)
      }
    }
    sendNextFrame()
  }

  ws.onmessage = (event) => {
    try {
      const response = JSON.parse(event.data as string)
      if (response.code !== 0) {
        onError(new Error(`iFlytek error ${response.code}: ${response.message}`))
        ws.close()
        return
      }
      const text = parseIFlytekResponse(response)
      const isLast = response.data?.status === 2
      onResult(text, isLast)
      if (isLast) {
        ws.close()
        onComplete()
      }
    } catch (err) {
      onError(err instanceof Error ? err : new Error(String(err)))
      ws.close()
    }
  }

  ws.onerror = () => {
    onError(new Error('WebSocket connection failed'))
  }

  ws.onclose = () => {
    // Connection closed
  }
}

export function createIFlytekAdapter(config: IFlytekConfig): STTAdapter {
  return {
    name: 'iflytek',
    capabilities: { streaming: true },

    async transcribe(audio: ArrayBuffer, options: STTOptions): Promise<string> {
      const url = await buildAuthUrl(config)
      const frames = splitIntoFrames(audio)

      return new Promise<string>((resolve, reject) => {
        let accumulated = ''

        openWebSocket(
          url,
          config,
          options.lang,
          frames,
          (text, isLast) => {
            accumulated += text
            if (isLast) {
              resolve(accumulated)
            }
          },
          reject,
          () => {
            resolve(accumulated)
          },
        )
      })
    },

    async transcribeStream(
      audioStream: ReadableStream<ArrayBuffer>,
      options: STTOptions,
      onPartial: (text: string) => void,
    ): Promise<string> {
      const url = await buildAuthUrl(config)

      // Collect all chunks first, then send via WebSocket
      const reader = audioStream.getReader()
      const chunks: ArrayBuffer[] = []

      try {
        for (;;) {
          const { done, value } = await reader.read()
          if (done) break
          if (value) chunks.push(value)
        }
      } finally {
        reader.releaseLock()
      }

      const totalLength = chunks.reduce((sum, chunk) => sum + chunk.byteLength, 0)
      const combined = new Uint8Array(totalLength)
      let offset = 0
      for (const chunk of chunks) {
        combined.set(new Uint8Array(chunk), offset)
        offset += chunk.byteLength
      }

      const frames = splitIntoFrames(combined.buffer)

      return new Promise<string>((resolve, reject) => {
        let accumulated = ''

        openWebSocket(
          url,
          config,
          options.lang,
          frames,
          (text) => {
            accumulated += text
            onPartial(accumulated)
          },
          reject,
          () => {
            resolve(accumulated)
          },
        )
      })
    },
  }
}
