import AppKit
import Foundation
import Observation
import SwiftUI

@Observable @MainActor
final class FloatingViewModel {

    // MARK: - State

    var pipelineState: PipelineState = .idle
    var recordingDuration: TimeInterval = 0
    var audioLevels: [Float] = Array(repeating: 0, count: 20)
    var lastResult: String?
    var lastSource: String?

    // MARK: - Dependencies (set externally)

    var configManager: ConfigManager?
    var historyManager: HistoryManager?

    // MARK: - Private

    private let pipelineEngine: PipelineEngine
    private let audioRecorder: any AudioRecording
    private let textOutputService: any TextOutputting
    private var recordingTimer: Timer?
    private var collapseTask: Task<Void, Never>?
    private var pipelineTask: Task<Void, Never>?

    /// Tracks the most recent non-Verbo frontmost app — robust against timing issues.
    private let frontmostTracker = FrontmostAppTracker()

    /// Target app captured at recording start (from tracker).
    private var targetApplication: NSRunningApplication?

    /// Timestamp of the second hotkey press (stop recording). Used to measure
    /// the user-perceived end-to-end latency until the final result appears.
    private var stopRequestedAt: Date?

    // MARK: - Init

    init(
        audioRecorder: any AudioRecording = AudioRecorder(),
        textOutputService: any TextOutputting = TextOutputService(),
        pipelineEngine: PipelineEngine = PipelineEngine()
    ) {
        self.audioRecorder = audioRecorder
        self.textOutputService = textOutputService
        self.pipelineEngine = pipelineEngine
    }

    // MARK: - Computed

    var isIdle: Bool { pipelineState.isIdle }
    var isRecording: Bool { pipelineState.isRecording }

    /// Derived from `configManager.config` so the pill always reflects the
    /// latest scene + hotkey after settings edits. Because `ConfigManager`
    /// is `@Observable`, SwiftUI re-renders any view that reads these when
    /// the config changes.
    var currentSceneName: String {
        configManager?.defaultScene()?.name ?? "Verbo"
    }
    var currentHotkeyHint: String {
        HotkeyManager.displayString(for: configManager?.defaultScene()?.hotkey.toggleRecord ?? "")
    }

    var isTranscribing: Bool {
        if case .transcribing = pipelineState { return true }
        return false
    }

    var pillDotColor: Color {
        switch pipelineState {
        case .idle: DesignTokens.Colors.stoneGray
        case .recording: DesignTokens.Colors.terracotta
        case .transcribing, .processing: DesignTokens.Colors.coral
        case .done: Color.green
        case .error: DesignTokens.Colors.errorCrimson
        }
    }

    var timerText: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Actions

    var isActive: Bool { isRecording || isTranscribing }

    func toggleRecording() {
        if isActive { stopRecording() } else { startRecording() }
    }

    func startRecording() {
        guard isIdle || pipelineState.isDone || pipelineState.isError else { return }

        // Cancel any lingering previous pipeline
        pipelineTask?.cancel()
        pipelineTask = nil

        // Use the tracked frontmost app instead of NSWorkspace.frontmostApplication.
        // The tracker keeps the most recent non-self app regardless of momentary
        // focus shifts (e.g. toast hover, system notifications).
        targetApplication = frontmostTracker.target
        Log.ui.info("Captured target app: \(self.targetApplication?.bundleIdentifier ?? "nil", privacy: .public)")

        collapseTask?.cancel()
        lastResult = nil
        lastSource = nil
        stopRequestedAt = nil
        pipelineState = .recording
        recordingDuration = 0

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.recordingDuration += 0.1 }
        }

        Task {
            let audioStream = await audioRecorder.start()
            await runPipeline(audioStream: audioStream)
        }
    }

    func stopRecording() {
        guard isRecording || isTranscribing else { return }
        // Capture the moment the user asked to stop — used as the anchor for
        // the user-perceived end-to-end latency (until final result appears).
        // Only the first call wins so that retries / double-invocations don't
        // reset the anchor.
        if stopRequestedAt == nil {
            stopRequestedAt = Date()
        }
        recordingTimer?.invalidate()
        recordingTimer = nil
        Task { _ = await audioRecorder.stop() }
    }

    func pillTapped() {
        switch pipelineState {
        case .idle:
            startRecording()
        case .recording, .transcribing:
            // Stop recording and send audio for processing
            stopRecording()
        case .done:
            collapseTask?.cancel()
            pipelineState = .idle
        case .error:
            pipelineState = .idle
        default:
            break
        }
    }

    func retry() {
        pipelineState = .idle
        startRecording()
    }

    func pollAudioLevels() async {
        audioLevels = await audioRecorder.audioLevels
    }

    // MARK: - Private Pipeline

    private func runPipeline(audioStream: AsyncStream<Data>) async {
        guard let config = configManager?.config,
              let scene = configManager?.defaultScene() else { return }

        let sttConfigs = config.providers.stt
        let llmConfigs = config.providers.llm

        let getSTT: @Sendable (String) -> (any STTAdapter)? = { provider in
            guard let cfg = sttConfigs[provider] else { return nil }
            return IFlytekSTTAdapter(
                appId: cfg.appId,
                apiKey: cfg.apiKey,
                apiSecret: cfg.apiSecret
            )
        }

        let getLLM: @Sendable (String) -> (any LLMAdapter)? = { provider in
            guard let cfg = llmConfigs[provider] else { return nil }
            return OpenAILLMAdapter(
                apiKey: cfg.apiKey,
                model: cfg.model,
                baseUrl: cfg.baseUrl
            )
        }

        let steps = scene.pipeline
        let outputMode = scene.output
        let sceneId = scene.id
        let sceneName = scene.name
        let pipelineSteps = scene.pipeline.map { "\($0.type.rawValue):\($0.provider)" }

        pipelineTask = Task {
            defer {
                // ALWAYS stop the recorder when pipeline ends (success or error)
                Task { _ = await audioRecorder.stop() }
            }
            do {
                for try await state in await pipelineEngine.execute(
                    steps: steps,
                    audioStream: audioStream,
                    getSTT: getSTT,
                    getLLM: getLLM
                ) {
                    pipelineState = state
                    if case .done(let result, let source) = state {
                        // Capture perceived latency BEFORE focus-restore sleep
                        // and text output — "seeing the complete result" is
                        // the moment the bubble expands with the final text.
                        let latencyMs: Int? = stopRequestedAt.map {
                            Int(Date().timeIntervalSince($0) * 1000)
                        }

                        // Empty result is a recognition failure, not a
                        // success: don't type empty into the focused app and
                        // don't write a noise-only history record.
                        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            pipelineState = .error(
                                message: String(localized: "pipeline.error.no_speech")
                            )
                            continue
                        }

                        lastResult = result
                        lastSource = source

                        // Restore focus to the app that was frontmost when recording started.
                        // CGEvent keyboard input goes to whatever is frontmost *at the moment
                        // of the event*, so we have to make sure the target app is actually
                        // active before typing. A fixed-duration sleep is not enough for
                        // long recordings, because macOS may have put the target into a
                        // background state that takes 100–500 ms to wake up.
                        if let target = targetApplication,
                           target.bundleIdentifier != Bundle.main.bundleIdentifier {
                            await activateAndWait(for: target, timeout: .milliseconds(600))
                        }

                        let status = await textOutputService.output(text: result, mode: outputMode)
                        let record = HistoryRecord(
                            id: UUID(),
                            timestamp: Date(),
                            sceneId: sceneId,
                            sceneName: sceneName,
                            originalText: source ?? result,
                            finalText: result,
                            outputStatus: status,
                            pipelineSteps: pipelineSteps,
                            endToEndLatencyMs: latencyMs
                        )
                        historyManager?.add(record)
                        try? historyManager?.save()
                        scheduleCollapse()
                    }
                }
            } catch {
                pipelineState = .error(message: error.localizedDescription)
            }
        }
    }

    /// Activate the target app and poll until `NSWorkspace.frontmostApplication`
    /// actually matches (or until timeout). `NSRunningApplication.activate()` is
    /// async — on long recordings the previous frontmost app may have been
    /// demoted to background state and takes well over 50 ms to come back.
    private func activateAndWait(
        for target: NSRunningApplication,
        timeout: Duration
    ) async {
        target.activate()

        let start = Date()
        let timeoutSecs = Double(timeout.components.seconds) +
            Double(timeout.components.attoseconds) * 1e-18
        while Date().timeIntervalSince(start) < timeoutSecs {
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == target.bundleIdentifier {
                // Give the target one more tick to actually accept key events.
                try? await Task.sleep(for: .milliseconds(20))
                return
            }
            try? await Task.sleep(for: .milliseconds(15))
        }
        Log.ui.error("Target \(target.bundleIdentifier ?? "?", privacy: .public) failed to become frontmost within timeout")
    }

    private func scheduleCollapse() {
        let delay = configManager?.config.general.autoCollapseDelay ?? 1.5
        // Negative = never collapse. Zero = collapse immediately.
        guard delay >= 0 else { return }
        collapseTask = Task {
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            if !Task.isCancelled {
                if configManager?.config.general.copyOnDismiss == true,
                   let result = lastResult {
                    textOutputService.writeToClipboard(result)
                }
                pipelineState = .idle
            }
        }
    }
}
