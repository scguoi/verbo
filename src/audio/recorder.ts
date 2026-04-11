export interface AudioRecorder {
  start(): Promise<ReadableStream<ArrayBuffer>>
  stop(): Promise<ArrayBuffer>
  isRecording(): boolean
}

interface RecorderState {
  readonly recording: boolean
  readonly mediaRecorder: MediaRecorder | null
  readonly mediaStream: MediaStream | null
  readonly chunks: readonly ArrayBuffer[]
  readonly streamController: ReadableStreamDefaultController<ArrayBuffer> | null
}

const initialState: RecorderState = {
  recording: false,
  mediaRecorder: null,
  mediaStream: null,
  chunks: [],
  streamController: null,
}

const AUDIO_CONSTRAINTS: MediaStreamConstraints = {
  audio: {
    sampleRate: 16000,
    channelCount: 1,
    echoCancellation: true,
    noiseSuppression: true,
  },
}

const TIMESLICE_MS = 100

function concatArrayBuffers(buffers: readonly ArrayBuffer[]): ArrayBuffer {
  const totalLength = buffers.reduce((sum, buf) => sum + buf.byteLength, 0)
  const result = new Uint8Array(totalLength)
  let offset = 0
  for (const buf of buffers) {
    result.set(new Uint8Array(buf), offset)
    offset += buf.byteLength
  }
  return result.buffer
}

function stopMediaStream(stream: MediaStream | null): void {
  if (stream) {
    stream.getTracks().forEach((track) => track.stop())
  }
}

export function createAudioRecorder(): AudioRecorder {
  let state: RecorderState = { ...initialState }

  const updateState = (patch: Partial<RecorderState>): void => {
    state = { ...state, ...patch }
  }

  const start = async (): Promise<ReadableStream<ArrayBuffer>> => {
    if (state.recording) {
      throw new Error('Already recording')
    }

    const mediaStream = await navigator.mediaDevices.getUserMedia(AUDIO_CONSTRAINTS)
    const mediaRecorder = new MediaRecorder(mediaStream)

    const readableStream = new ReadableStream<ArrayBuffer>({
      start(controller) {
        updateState({ streamController: controller })
      },
      cancel() {
        if (state.recording) {
          mediaRecorder.stop()
          stopMediaStream(state.mediaStream)
          updateState({
            recording: false,
            mediaRecorder: null,
            mediaStream: null,
            chunks: [],
            streamController: null,
          })
        }
      },
    })

    mediaRecorder.ondataavailable = (event: BlobEvent) => {
      if (event.data.size > 0) {
        event.data.arrayBuffer().then((buffer) => {
          updateState({ chunks: [...state.chunks, buffer] })
          if (state.streamController) {
            try {
              state.streamController.enqueue(buffer)
            } catch {
              // Stream may have been closed; ignore enqueue errors
            }
          }
        })
      }
    }

    mediaRecorder.onstop = () => {
      if (state.streamController) {
        try {
          state.streamController.close()
        } catch {
          // Stream may already be closed
        }
      }
    }

    updateState({
      recording: true,
      mediaRecorder,
      mediaStream,
      chunks: [],
    })

    mediaRecorder.start(TIMESLICE_MS)

    return readableStream
  }

  const stop = async (): Promise<ArrayBuffer> => {
    if (!state.recording || !state.mediaRecorder) {
      throw new Error('Not recording')
    }

    const { mediaRecorder, mediaStream } = state

    return new Promise<ArrayBuffer>((resolve) => {
      const previousOnStop = mediaRecorder.onstop

      mediaRecorder.onstop = (event) => {
        if (previousOnStop) {
          previousOnStop.call(mediaRecorder, event)
        }
        stopMediaStream(mediaStream)
        const combined = concatArrayBuffers(state.chunks)
        updateState({
          recording: false,
          mediaRecorder: null,
          mediaStream: null,
          chunks: [],
          streamController: null,
        })
        resolve(combined)
      }

      mediaRecorder.stop()
    })
  }

  const isRecording = (): boolean => state.recording

  return { start, stop, isRecording }
}
