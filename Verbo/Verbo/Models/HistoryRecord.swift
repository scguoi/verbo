import Foundation

// MARK: - History Record

public struct HistoryRecord: Codable, Identifiable, Sendable, Equatable {

    // MARK: - Output Status

    public enum OutputStatus: String, Codable, Sendable {
        case inserted
        case copied
        case failed
    }

    // MARK: - Properties

    public let id: UUID
    public let timestamp: Date
    public let sceneId: String
    public let sceneName: String
    public let originalText: String
    public let finalText: String
    public let outputStatus: OutputStatus
    public let pipelineSteps: [String]

    // MARK: - Computed Properties

    public var hasLLMProcessing: Bool {
        originalText != finalText
    }

    // MARK: - Init

    public init(
        id: UUID,
        timestamp: Date,
        sceneId: String,
        sceneName: String,
        originalText: String,
        finalText: String,
        outputStatus: OutputStatus,
        pipelineSteps: [String]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sceneId = sceneId
        self.sceneName = sceneName
        self.originalText = originalText
        self.finalText = finalText
        self.outputStatus = outputStatus
        self.pipelineSteps = pipelineSteps
    }
}
