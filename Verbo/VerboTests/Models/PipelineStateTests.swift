import Testing
@testable import Verbo

@Suite("PipelineState Tests")
struct PipelineStateTests {

    @Test("idle state isIdle is true")
    func idleIsIdle() {
        let state = PipelineState.idle
        #expect(state.isIdle == true)
    }

    @Test("idle state isRecording is false")
    func idleIsNotRecording() {
        let state = PipelineState.idle
        #expect(state.isRecording == false)
    }

    @Test("idle state isDone is false")
    func idleIsNotDone() {
        let state = PipelineState.idle
        #expect(state.isDone == false)
    }

    @Test("idle state isError is false")
    func idleIsNotError() {
        let state = PipelineState.idle
        #expect(state.isError == false)
    }

    @Test("recording state isRecording is true")
    func recordingIsRecording() {
        let state = PipelineState.recording
        #expect(state.isRecording == true)
    }

    @Test("recording state isIdle is false")
    func recordingIsNotIdle() {
        let state = PipelineState.recording
        #expect(state.isIdle == false)
    }

    @Test("transcribing state has partial text accessible")
    func transcribingPartialText() {
        let state = PipelineState.transcribing(partial: "hello")
        if case .transcribing(let partial) = state {
            #expect(partial == "hello")
        } else {
            Issue.record("Expected transcribing state")
        }
    }

    @Test("processing state has source and partial text accessible")
    func processingAssociatedValues() {
        let state = PipelineState.processing(source: "original", partial: "processed")
        if case .processing(let source, let partial) = state {
            #expect(source == "original")
            #expect(partial == "processed")
        } else {
            Issue.record("Expected processing state")
        }
    }

    @Test("done state isDone is true")
    func doneIsDone() {
        let state = PipelineState.done(result: "final text", source: "source text")
        #expect(state.isDone == true)
    }

    @Test("done state has result and source accessible")
    func doneAssociatedValues() {
        let state = PipelineState.done(result: "final text", source: "source text")
        if case .done(let result, let source) = state {
            #expect(result == "final text")
            #expect(source == "source text")
        } else {
            Issue.record("Expected done state")
        }
    }

    @Test("done state with nil source")
    func doneWithNilSource() {
        let state = PipelineState.done(result: "result", source: nil)
        if case .done(let result, let source) = state {
            #expect(result == "result")
            #expect(source == nil)
        } else {
            Issue.record("Expected done state")
        }
    }

    @Test("error state isError is true")
    func errorIsError() {
        let state = PipelineState.error(message: "something went wrong")
        #expect(state.isError == true)
    }

    @Test("error state has message accessible")
    func errorAssociatedValue() {
        let state = PipelineState.error(message: "something went wrong")
        if case .error(let message) = state {
            #expect(message == "something went wrong")
        } else {
            Issue.record("Expected error state")
        }
    }

    @Test("states are equatable")
    func statesEquatable() {
        #expect(PipelineState.idle == PipelineState.idle)
        #expect(PipelineState.recording == PipelineState.recording)
        #expect(PipelineState.transcribing(partial: "hi") == PipelineState.transcribing(partial: "hi"))
        #expect(PipelineState.transcribing(partial: "hi") != PipelineState.transcribing(partial: "bye"))
        #expect(PipelineState.idle != PipelineState.recording)
    }
}
