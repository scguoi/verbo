import Testing
import SwiftUI
@testable import Verbo

// MARK: - View Smoke Tests

@Suite("View Smoke Tests")
@MainActor
struct ViewSmokeTests {

    // MARK: - PillView Tests

    @Test("PillView body evaluates without crash in idle state")
    func pillViewIdle() {
        let view = PillView(
            state: .idle,
            sceneName: "Test",
            hotkeyHint: "⌥D",
            timerText: "0:00",
            audioLevels: [],
            dotColor: .gray,
            onTap: {}
        )
        _ = view.body
    }

    @Test("PillView body evaluates without crash in recording state")
    func pillViewRecording() {
        let levels = [Float](repeating: 0.5, count: 20)
        let view = PillView(
            state: .recording,
            sceneName: "Test",
            hotkeyHint: "⌥D",
            timerText: "0:05",
            audioLevels: levels,
            dotColor: .red,
            onTap: {}
        )
        _ = view.body
    }

    @Test("PillView body evaluates without crash in transcribing state")
    func pillViewTranscribing() {
        let view = PillView(
            state: .transcribing(partial: "你好"),
            sceneName: "Test",
            hotkeyHint: "⌥D",
            timerText: "0:03",
            audioLevels: [],
            dotColor: .orange,
            onTap: {}
        )
        _ = view.body
    }

    @Test("PillView body evaluates without crash in processing state")
    func pillViewProcessing() {
        let view = PillView(
            state: .processing(source: "raw", partial: "polished"),
            sceneName: "Test",
            hotkeyHint: "⌥D",
            timerText: "0:04",
            audioLevels: [],
            dotColor: .orange,
            onTap: {}
        )
        _ = view.body
    }

    @Test("PillView body evaluates without crash in done state")
    func pillViewDone() {
        let view = PillView(
            state: .done(result: "result", source: nil),
            sceneName: "Test",
            hotkeyHint: "⌥D",
            timerText: "0:06",
            audioLevels: [],
            dotColor: .green,
            onTap: {}
        )
        _ = view.body
    }

    @Test("PillView body evaluates without crash in error state")
    func pillViewError() {
        let view = PillView(
            state: .error(message: "Network error"),
            sceneName: "Test",
            hotkeyHint: "⌥D",
            timerText: "0:00",
            audioLevels: [],
            dotColor: .red,
            onTap: {}
        )
        _ = view.body
    }

    // MARK: - WaveformView Tests

    @Test("WaveformView body evaluates without crash with normal levels")
    func waveformViewNormalLevels() {
        let view = WaveformView(levels: [0.1, 0.5, 0.8, 0.3, 0.6])
        _ = view.body
    }

    @Test("WaveformView body evaluates without crash with empty levels")
    func waveformViewEmptyLevels() {
        let view = WaveformView(levels: [])
        _ = view.body
    }

    @Test("WaveformView body evaluates without crash with max levels")
    func waveformViewMaxLevels() {
        let levels = [Float](repeating: 1.0, count: 20)
        let view = WaveformView(levels: levels)
        _ = view.body
    }
}
