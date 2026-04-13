import Testing
import Foundation
@testable import Verbo

@Suite("FloatingViewModel State Machine Tests")
@MainActor
struct FloatingViewModelTests {

    private func makeViewModel() -> (FloatingViewModel, MockAudioRecorder, MockTextOutputService) {
        let recorder = MockAudioRecorder()
        let output = MockTextOutputService()
        let vm = FloatingViewModel(audioRecorder: recorder, textOutputService: output)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let configManager = ConfigManager(directory: dir)
        configManager.load()
        vm.configManager = configManager
        vm.historyManager = HistoryManager(directory: dir)
        return (vm, recorder, output)
    }

    // MARK: - Initial State

    @Test("Initial state: isIdle is true, all others false, lastResult nil")
    func initialState() {
        let (vm, _, _) = makeViewModel()
        #expect(vm.isIdle == true)
        #expect(vm.isRecording == false)
        #expect(vm.isTranscribing == false)
        #expect(vm.isActive == false)
        #expect(vm.lastResult == nil)
    }

    // MARK: - pillTapped

    @Test("pillTapped in idle with no lastResult starts recording")
    func pillTappedIdleNoResult() async {
        let (vm, recorder, _) = makeViewModel()
        vm.pillTapped()
        // Yield to allow the async Task inside startRecording() to execute
        await Task.yield()
        #expect(recorder.startCallCount == 1)
    }

    @Test("pillTapped in .recording calls recorder stop")
    func pillTappedRecording() async {
        let (vm, recorder, _) = makeViewModel()
        vm.pipelineState = .recording
        vm.pillTapped()
        // Yield to allow the async Task inside stopRecording() to execute
        await Task.yield()
        #expect(recorder.stopCallCount == 1)
    }

    @Test("pillTapped in .transcribing calls recorder stop")
    func pillTappedTranscribing() async {
        let (vm, recorder, _) = makeViewModel()
        vm.pipelineState = .transcribing(partial: "hello")
        vm.pillTapped()
        // Yield to allow the async Task inside stopRecording() to execute
        await Task.yield()
        #expect(recorder.stopCallCount == 1)
    }

    @Test("pillTapped in .done dismisses to idle")
    func pillTappedDone() {
        let (vm, _, _) = makeViewModel()
        vm.pipelineState = .done(result: "result", source: nil)
        vm.pillTapped()
        #expect(vm.isIdle == true)
    }

    @Test("pillTapped in .error dismisses to idle")
    func pillTappedError() {
        let (vm, _, _) = makeViewModel()
        vm.pipelineState = .error(message: "oops")
        vm.pillTapped()
        #expect(vm.isIdle == true)
    }

    // MARK: - toggleRecording

    @Test("toggleRecording from idle starts recording")
    func toggleRecordingFromIdle() async {
        let (vm, recorder, _) = makeViewModel()
        vm.toggleRecording()
        await Task.yield()
        #expect(recorder.startCallCount == 1)
    }

    @Test("toggleRecording from .recording stops")
    func toggleRecordingFromRecording() async {
        let (vm, recorder, _) = makeViewModel()
        vm.pipelineState = .recording
        vm.toggleRecording()
        await Task.yield()
        #expect(recorder.stopCallCount == 1)
    }

    @Test("toggleRecording from .transcribing stops")
    func toggleRecordingFromTranscribing() async {
        let (vm, recorder, _) = makeViewModel()
        vm.pipelineState = .transcribing(partial: "partial")
        vm.toggleRecording()
        await Task.yield()
        #expect(recorder.stopCallCount == 1)
    }

    // MARK: - isActive

    @Test("isActive is true during .recording")
    func isActiveDuringRecording() {
        let (vm, _, _) = makeViewModel()
        vm.pipelineState = .recording
        #expect(vm.isActive == true)
    }

    @Test("isActive is true during .transcribing")
    func isActiveDuringTranscribing() {
        let (vm, _, _) = makeViewModel()
        vm.pipelineState = .transcribing(partial: "")
        #expect(vm.isActive == true)
    }

    @Test("isActive is false in idle")
    func isActiveInIdle() {
        let (vm, _, _) = makeViewModel()
        #expect(vm.isActive == false)
    }

    @Test("isActive is false in done")
    func isActiveInDone() {
        let (vm, _, _) = makeViewModel()
        vm.pipelineState = .done(result: "r", source: nil)
        #expect(vm.isActive == false)
    }

    // MARK: - pillDotColor

    @Test("pillDotColor is stoneGray in idle")
    func pillDotColorIdle() {
        let (vm, _, _) = makeViewModel()
        #expect(vm.pillDotColor == DesignTokens.Colors.stoneGray)
    }

    @Test("pillDotColor is terracotta in recording")
    func pillDotColorRecording() {
        let (vm, _, _) = makeViewModel()
        vm.pipelineState = .recording
        #expect(vm.pillDotColor == DesignTokens.Colors.terracotta)
    }

    @Test("pillDotColor is errorCrimson in error")
    func pillDotColorError() {
        let (vm, _, _) = makeViewModel()
        vm.pipelineState = .error(message: "err")
        #expect(vm.pillDotColor == DesignTokens.Colors.errorCrimson)
    }

    // MARK: - timerText

    @Test("timerText formats 65.3 seconds as 1:05")
    func timerText65Seconds() {
        let (vm, _, _) = makeViewModel()
        vm.recordingDuration = 65.3
        #expect(vm.timerText == "1:05")
    }

    @Test("timerText formats 0 seconds as 0:00")
    func timerTextZero() {
        let (vm, _, _) = makeViewModel()
        vm.recordingDuration = 0
        #expect(vm.timerText == "0:00")
    }

    // MARK: - startRecording resets state

    @Test("startRecording resets lastResult, lastSource, recordingDuration")
    func startRecordingResetsState() async {
        let (vm, _, _) = makeViewModel()
        vm.lastResult = "previous result"
        vm.lastSource = "previous source"
        vm.recordingDuration = 99.0
        vm.startRecording()
        // State is reset synchronously before the async Task launches
        #expect(vm.lastResult == nil)
        #expect(vm.lastSource == nil)
        #expect(vm.recordingDuration == 0)
    }
}
