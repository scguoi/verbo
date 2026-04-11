import Foundation

// MARK: - Pipeline State

public enum PipelineState: Sendable, Equatable {
    case idle
    case recording
    case transcribing(partial: String)
    case processing(source: String, partial: String)
    case done(result: String, source: String?)
    case error(message: String)

    // MARK: - Computed Properties

    public var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    public var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    public var isDone: Bool {
        if case .done = self { return true }
        return false
    }

    public var isError: Bool {
        if case .error = self { return true }
        return false
    }
}
