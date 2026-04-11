export type OutputStatus = 'inserted' | 'copied' | 'failed'

export interface HistoryRecord {
  readonly id: string
  readonly timestamp: number
  readonly sceneId: string
  readonly sceneName: string
  readonly originalText: string
  readonly finalText: string
  readonly outputStatus: OutputStatus
  readonly pipelineSteps: readonly string[]
}
