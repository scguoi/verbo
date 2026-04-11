export interface LLMOptions {
  readonly prompt: string
  readonly model?: string
}

export interface LLMAdapter {
  readonly name: string
  complete(options: LLMOptions): Promise<string>
  completeStream?(
    options: LLMOptions,
    onChunk: (text: string) => void,
  ): Promise<string>
}
