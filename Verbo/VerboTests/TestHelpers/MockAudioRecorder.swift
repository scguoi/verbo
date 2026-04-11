import Foundation
@testable import Verbo

final class MockAudioRecorder: AudioRecording, @unchecked Sendable {
    var isRecording = false
    var audioLevels: [Float] = Array(repeating: 0, count: 20)
    var startCallCount = 0
    var stopCallCount = 0
    private var continuation: AsyncStream<Data>.Continuation?

    func start() async -> AsyncStream<Data> {
        startCallCount += 1
        isRecording = true
        return AsyncStream { self.continuation = $0 }
    }

    func stop() async -> Data {
        stopCallCount += 1
        isRecording = false
        continuation?.finish()
        continuation = nil
        return Data()
    }

    func feedAudio(_ data: Data) {
        continuation?.yield(data)
    }

    func finishStream() {
        continuation?.finish()
    }
}
