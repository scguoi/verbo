import type { LLMAdapter, LLMOptions } from './types'

export interface OpenAIConfig {
  readonly apiKey: string
  readonly model: string
  readonly baseUrl: string
}

function buildUrl(baseUrl: string): string {
  const base = baseUrl.endsWith('/') ? baseUrl.slice(0, -1) : baseUrl
  return `${base}/chat/completions`
}

function buildHeaders(apiKey: string): Record<string, string> {
  return {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${apiKey}`,
  }
}

function buildBody(model: string, prompt: string, stream: boolean): string {
  return JSON.stringify({
    model,
    messages: [{ role: 'user', content: prompt }],
    stream,
  })
}

function resolveModel(config: OpenAIConfig, options: LLMOptions): string {
  return options.model ?? config.model
}

async function handleErrorResponse(response: Response): Promise<never> {
  const body = await response.text()
  throw new Error(`OpenAI API error ${response.status}: ${body}`)
}

function parseSSELine(line: string): string | null {
  if (!line.startsWith('data: ')) {
    return null
  }
  const data = line.slice(6).trim()
  if (data === '[DONE]') {
    return null
  }
  try {
    const parsed = JSON.parse(data)
    return parsed.choices?.[0]?.delta?.content ?? null
  } catch {
    return null
  }
}

export function createOpenAIAdapter(config: OpenAIConfig): LLMAdapter {
  return {
    name: 'openai',

    async complete(options: LLMOptions): Promise<string> {
      const model = resolveModel(config, options)
      const url = buildUrl(config.baseUrl)

      const response = await fetch(url, {
        method: 'POST',
        headers: buildHeaders(config.apiKey),
        body: buildBody(model, options.prompt, false),
      })

      if (!response.ok) {
        return handleErrorResponse(response)
      }

      const json = await response.json()
      return json.choices?.[0]?.message?.content ?? ''
    },

    async completeStream(
      options: LLMOptions,
      onChunk: (text: string) => void,
    ): Promise<string> {
      const model = resolveModel(config, options)
      const url = buildUrl(config.baseUrl)

      const response = await fetch(url, {
        method: 'POST',
        headers: buildHeaders(config.apiKey),
        body: buildBody(model, options.prompt, true),
      })

      if (!response.ok) {
        return handleErrorResponse(response)
      }

      const reader = response.body!.getReader()
      const decoder = new TextDecoder()
      let accumulated = ''
      let buffer = ''

      try {
        for (;;) {
          const { done, value } = await reader.read()
          if (done) break

          buffer += decoder.decode(value, { stream: true })
          const lines = buffer.split('\n')
          buffer = lines.pop() ?? ''

          for (const line of lines) {
            const content = parseSSELine(line)
            if (content !== null) {
              accumulated += content
              onChunk(accumulated)
            }
          }
        }

        // Process remaining buffer
        if (buffer.trim()) {
          const content = parseSSELine(buffer)
          if (content !== null) {
            accumulated += content
            onChunk(accumulated)
          }
        }
      } finally {
        reader.releaseLock()
      }

      return accumulated
    },
  }
}
