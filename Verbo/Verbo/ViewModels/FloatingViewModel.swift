import Foundation
import Observation
import SwiftUI

@Observable @MainActor
final class FloatingViewModel {

    // MARK: - State

    var pipelineState: PipelineState = .idle
    var currentSceneName: String = "Verbo"
    var currentHotkeyHint: String = "Alt+D"
    var recordingDuration: TimeInterval = 0
    var audioLevels: [Float] = Array(repeating: 0, count: 5)
    var isExpanded: Bool = false
    var lastResult: String?
    var lastSource: String?

    // MARK: - Dependencies (set externally)

    var configManager: ConfigManager?
    var historyManager: HistoryManager?

    // MARK: - Private

    private let pipelineEngine = PipelineEngine()
    private let audioRecorder = AudioRecorder()
    private let textOutputService = TextOutputService()
    private var recordingTimer: Timer?
    private var collapseTask: Task<Void, Never>?
    private var pipelineTask: Task<Void, Never>?

    // MARK: - Computed

    var isIdle: Bool { pipelineState.isIdle }
    var isRecording: Bool { pipelineState.isRecording }

    var pillDotColor: Color {
        switch pipelineState {
        case .idle: DesignTokens.Colors.stoneGray
        case .recording: DesignTokens.Colors.terracotta
        case .transcribing, .processing: DesignTokens.Colors.coral
        case .done: Color.green
        case .error: DesignTokens.Colors.errorCrimson
        }
    }

    var shouldShowBubble: Bool {
        switch pipelineState {
        case .idle, .recording: isExpanded && lastResult != nil
        case .transcribing, .processing, .done, .error: true
        }
    }

    var timerText: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Actions

    func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    func startRecording() {
        guard isIdle || pipelineState.isDone else { return }
        collapseTask?.cancel()
        isExpanded = false
        lastResult = nil
        lastSource = nil
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
        guard isRecording else { return }
        recordingTimer?.invalidate()
        recordingTimer = nil
        Task { _ = await audioRecorder.stop() }
    }

    func pillTapped() {
        switch pipelineState {
        case .idle:
            if lastResult != nil { isExpanded.toggle() } else { startRecording() }
        case .recording:
            stopRecording()
        case .done:
            collapseTask?.cancel()
            isExpanded.toggle()
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
            do {
                for try await state in await pipelineEngine.execute(
                    steps: steps,
                    audioStream: audioStream,
                    getSTT: getSTT,
                    getLLM: getLLM
                ) {
                    pipelineState = state
                    if case .done(let result, let source) = state {
                        lastResult = result
                        lastSource = source
                        isExpanded = true
                        let status = await textOutputService.output(text: result, mode: outputMode)
                        let record = HistoryRecord(
                            id: UUID(),
                            timestamp: Date(),
                            sceneId: sceneId,
                            sceneName: sceneName,
                            originalText: source ?? result,
                            finalText: result,
                            outputStatus: status,
                            pipelineSteps: pipelineSteps
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

    private func scheduleCollapse() {
        let delay = configManager?.config.general.autoCollapseDelay ?? 1.5
        guard delay > 0 else { return }
        collapseTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            if !Task.isCancelled {
                pipelineState = .idle
                isExpanded = false
            }
        }
    }
}
