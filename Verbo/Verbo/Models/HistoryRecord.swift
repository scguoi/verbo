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
    /// End-to-end perceived latency: from the second hotkey press (stop recording)
    /// to the moment the final result is shown to the user.
    /// Nil for older records that predate this metric.
    public let endToEndLatencyMs: Int?

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
        pipelineSteps: [String],
        endToEndLatencyMs: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sceneId = sceneId
        self.sceneName = sceneName
        self.originalText = originalText
        self.finalText = finalText
        self.outputStatus = outputStatus
        self.pipelineSteps = pipelineSteps
        self.endToEndLatencyMs = endToEndLatencyMs
    }

    // MARK: - Codable (custom init for backward compat with old history.json)

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, sceneId, sceneName, originalText, finalText
        case outputStatus, pipelineSteps, endToEndLatencyMs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.timestamp = try c.decode(Date.self, forKey: .timestamp)
        self.sceneId = try c.decode(String.self, forKey: .sceneId)
        self.sceneName = try c.decode(String.self, forKey: .sceneName)
        self.originalText = try c.decode(String.self, forKey: .originalText)
        self.finalText = try c.decode(String.self, forKey: .finalText)
        self.outputStatus = try c.decode(OutputStatus.self, forKey: .outputStatus)
        self.pipelineSteps = try c.decode([String].self, forKey: .pipelineSteps)
        self.endToEndLatencyMs = try c.decodeIfPresent(Int.self, forKey: .endToEndLatencyMs)
    }
}
