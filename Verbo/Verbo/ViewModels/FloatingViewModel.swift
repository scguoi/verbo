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

        let t0 = DispatchTime.now().uptimeNanoseconds
        fileLog("[start] enter startRecording")

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

        fileLog("[start] pipelineState=.recording t+\(elapsedMs(since: t0))ms")

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.recordingDuration += 0.1 }
        }

        Task {
            fileLog("[start] Task begin t+\(elapsedMs(since: t0))ms")
            let audioStream = await audioRecorder.start()
            fileLog("[start] audioRecorder.start() returned t+\(elapsedMs(since: t0))ms")
            await runPipeline(audioStream: audioStream)
        }
    }

    /// Milliseconds elapsed since an uptime-nanosecond anchor.
    nonisolated private func elapsedMs(since startNs: UInt64) -> Int {
        Int((DispatchTime.now().uptimeNanoseconds &- startNs) / 1_000_000)
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
                        fileLog("[pipeline.done] resultLen=\(result.count) latencyMs=\(latencyMs ?? -1)")

                        lastResult = result
                        lastSource = source

                        // Restore focus to the app that was frontmost when recording started.
                        // CGEvent keyboard input goes to whatever is frontmost *at the moment
                        // of the event*, so we have to make sure the target app is actually
                        // active before typing. A fixed-duration sleep is not enough for
                        // long recordings, because macOS may have put the target into a
                        // background state that takes 100–500 ms to wake up.
                        let frontmostBefore = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
                        fileLog("[pipeline.done] target=\(targetApplication?.bundleIdentifier ?? "nil") frontmost=\(frontmostBefore)")
                        if let target = targetApplication,
                           target.bundleIdentifier != Bundle.main.bundleIdentifier {
                            await activateAndWait(for: target, timeout: .milliseconds(600))
                        } else {
                            fileLog("[pipeline.done] SKIP activation (target nil or self)")
                        }

                        let frontmostBeforeOutput = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
                        fileLog("[pipeline.done] outputting mode=\(outputMode) frontmost=\(frontmostBeforeOutput)")
                        let status = await textOutputService.output(text: result, mode: outputMode)
                        fileLog("[pipeline.done] status=\(status)")
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
        let targetBundle = target.bundleIdentifier ?? "?"
        fileLog("[activate] start target=\(targetBundle) active=\(target.isActive) terminated=\(target.isTerminated)")
        target.activate()

        let start = Date()
        let timeoutSecs = Double(timeout.components.seconds) +
            Double(timeout.components.attoseconds) * 1e-18
        while Date().timeIntervalSince(start) < timeoutSecs {
            let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            if frontmost == target.bundleIdentifier {
                let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
                fileLog("[activate] ok target=\(targetBundle) elapsedMs=\(elapsedMs)")
                try? await Task.sleep(for: .milliseconds(20))
                return
            }
            try? await Task.sleep(for: .milliseconds(15))
        }
        let frontmostBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
        fileLog("[activate] TIMEOUT target=\(targetBundle) frontmost=\(frontmostBundle) terminated=\(target.isTerminated)")
    }

    /// Append a timestamped line to ~/.verbo/debug.log.
    /// Format: `HH:mm:ss.SSS msg` — lets us correlate stages across components.
    private nonisolated func fileLog(_ msg: String) {
        DebugLog.write(msg)
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
