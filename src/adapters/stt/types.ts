export interface STTOptions {
  readonly lang: string
}

export interface STTAdapter {
  readonly name: string
  readonly capabilities: {
    readonly streaming: boolean
  }
  transcribe(audio: ArrayBuffer, options: STTOptions): Promise<string>
  transcribeStream?(
    audioStream: ReadableStream<ArrayBuffer>,
    options: STTOptions,
    onPartial: (text: string) => void,
  ): Promise<string>
}
