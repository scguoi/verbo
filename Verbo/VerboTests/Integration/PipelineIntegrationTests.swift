import Testing
import Foundation
@testable import Verbo

// MARK: - Pipeline Integration Tests

@Suite("Pipeline Integration Tests")
struct PipelineIntegrationTests {

    // MARK: - Test 1: STT-only pipeline state sequence

    @Test("STT-only pipeline emits transcribing then done")
    func sttOnlyPipelineStateSequence() async throws {
        let engine = PipelineEngine()
        let mockSTT = MockSTTAdapter()
        mockSTT.transcribeResult = "口语文字"

        let steps = [PipelineStep(type: .stt, provider: "mock", lang: "zh")]
        let audioStream = TestFixtures.audioStream()

        var states: [PipelineState] = []
        let stream = await engine.execute(
            steps: steps,
            audioStream: audioStream,
            getSTT: { _ in mockSTT },
            getLLM: { _ in nil }
        )

        for try await state in stream {
            states.append(state)
        }

        let hasTranscribing = states.contains { state in
            if case .transcribing = state { return true }
            return false
        }
        #expect(hasTranscribing, "Expected at least one .transcribing state")

        let last = states.last
        if case .done = last {
            // good
        } else {
            #expect(Bool(false), "Expected final state to be .done, got \(String(describing: last))")
        }
    }

    // MARK: - Test 2: STT+LLM pipeline flows through both steps

    @Test("STT+LLM pipeline produces correct result and source")
    func sttAndLLMPipelineFlowsCorrectly() async throws {
        let engine = PipelineEngine()
        let mockSTT = MockSTTAdapter()
        mockSTT.transcribeResult = "口语文字"

        let mockLLM = MockLLMAdapter()
        mockLLM.completeResult = "书面文字"

        let steps = [
            PipelineStep(type: .stt, provider: "mock-stt", lang: "zh"),
            PipelineStep(type: .llm, provider: "mock-llm", prompt: "{{input}}")
        ]
        let audioStream = TestFixtures.audioStream()

        var states: [PipelineState] = []
        let stream = await engine.execute(
            steps: steps,
            audioStream: audioStream,
            getSTT: { _ in mockSTT },
            getLLM: { _ in mockLLM }
        )

        for try await state in stream {
            states.append(state)
        }

        // Find the .done state
        var doneResult: String? = nil
        var doneSource: String? = nil
        for state in states {
            if case .done(let result, let source) = state {
                doneResult = result
                doneSource = source
            }
        }

        #expect(doneResult == "书面文字", "Expected result '书面文字', got '\(doneResult ?? "nil")'")
        #expect(doneSource == "口语文字", "Expected source '口语文字', got '\(doneSource ?? "nil")'")

        // Verify LLM received the STT output as part of prompt
        #expect(mockLLM.lastPrompt?.contains("口语文字") == true,
                "Expected LLM prompt to contain '口语文字', got '\(mockLLM.lastPrompt ?? "nil")'")
    }

    // MARK: - Test 3: Pipeline error when STT adapter not found

    @Test("Pipeline errors when STT adapter not found")
    func pipelineErrorWhenSTTAdapterNotFound() async throws {
        let engine = PipelineEngine()
        let steps = [PipelineStep(type: .stt, provider: "nonexistent", lang: "zh")]
        let audioStream = TestFixtures.audioStream()

        var states: [PipelineState] = []
        do {
            let stream = await engine.execute(
                steps: steps,
                audioStream: audioStream,
                getSTT: { _ in nil },
                getLLM: { _ in nil }
            )
            for try await state in stream {
                states.append(state)
            }
        } catch {
            // Expected to throw
        }

        let hasError = states.contains { state in
            if case .error = state { return true }
            return false
        }
        #expect(hasError, "Expected .error state when STT adapter not found")
    }

    // MARK: - Test 4: Pipeline error when LLM adapter not found

    @Test("Pipeline errors when LLM adapter not found")
    func pipelineErrorWhenLLMAdapterNotFound() async throws {
        let engine = PipelineEngine()
        let mockSTT = MockSTTAdapter()
        mockSTT.transcribeResult = "some text"

        let steps = [
            PipelineStep(type: .stt, provider: "mock-stt", lang: "zh"),
            PipelineStep(type: .llm, provider: "nonexistent", prompt: "{{input}}")
        ]
        let audioStream = TestFixtures.audioStream()

        var states: [PipelineState] = []
        do {
            let stream = await engine.execute(
                steps: steps,
                audioStream: audioStream,
                getSTT: { _ in mockSTT },
                getLLM: { _ in nil }
            )
            for try await state in stream {
                states.append(state)
            }
        } catch {
            // Expected to throw
        }

        let hasError = states.contains { state in
            if case .error = state { return true }
            return false
        }
        #expect(hasError, "Expected .error state when LLM adapter not found")
    }

    // MARK: - Test 5: Pipeline handles STT adapter throwing error

    @Test("Pipeline propagates STT adapter errors")
    func pipelineHandlesSTTAdapterThrowingError() async throws {
        let engine = PipelineEngine()
        let mockSTT = MockSTTAdapter()
        mockSTT.shouldThrow = URLError(.notConnectedToInternet)

        let steps = [PipelineStep(type: .stt, provider: "mock", lang: "zh")]
        let audioStream = TestFixtures.audioStream()

        var states: [PipelineState] = []
        var caughtError: Error? = nil
        do {
            let stream = await engine.execute(
                steps: steps,
                audioStream: audioStream,
                getSTT: { _ in mockSTT },
                getLLM: { _ in nil }
            )
            for try await state in stream {
                states.append(state)
            }
        } catch {
            caughtError = error
        }

        let hasError = states.contains { state in
            if case .error = state { return true }
            return false
        }
        // Either an .error state is produced OR the stream throws
        #expect(hasError || caughtError != nil,
                "Expected error to be propagated via .error state or thrown exception")
    }
}

// MARK: - Manager Lifecycle Tests

@Suite("Manager Lifecycle Tests")
@MainActor
struct ManagerLifecycleTests {

    // MARK: - Test 6: ConfigManager survives missing file

    @Test("ConfigManager uses defaults when config file is missing")
    func configManagerSurvivesMissingFile() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        // Do NOT create the directory — config file won't exist
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = ConfigManager(directory: tempDir)
        manager.load()

        #expect(manager.config.version == 1, "Expected version 1")
        #expect(manager.config.scenes.count == 3, "Expected 3 preset scenes")
    }

    // MARK: - Test 7: ConfigManager save then load round-trip

    @Test("ConfigManager save and load round-trip preserves defaultScene")
    func configManagerSaveThenLoadRoundTrip() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Load defaults and update defaultScene
        let manager1 = ConfigManager(directory: tempDir)
        manager1.load()

        var updated = manager1.config
        updated = AppConfig(
            version: updated.version,
            defaultScene: "polish",
            globalHotkey: updated.globalHotkey,
            scenes: updated.scenes,
            providers: updated.providers,
            general: updated.general
        )
        manager1.update(updated)
        try manager1.save()

        // Create a new manager with same dir and reload
        let manager2 = ConfigManager(directory: tempDir)
        manager2.load()

        #expect(manager2.config.defaultScene == "polish",
                "Expected defaultScene 'polish', got '\(manager2.config.defaultScene)'")
    }

    // MARK: - Test 8: HistoryManager add + search + persist

    @Test("HistoryManager add, search, save, and reload")
    func historyManagerAddSearchAndPersist() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = HistoryManager(directory: tempDir)
        manager.load()

        // Add two records
        let record1 = HistoryRecord(
            id: UUID(),
            timestamp: Date(),
            sceneId: "test",
            sceneName: "Test",
            originalText: "hello world",
            finalText: "hello world",
            outputStatus: .inserted,
            pipelineSteps: ["stt:mock"]
        )
        let record2 = HistoryRecord(
            id: UUID(),
            timestamp: Date(),
            sceneId: "test",
            sceneName: "Test",
            originalText: "goodbye",
            finalText: "goodbye",
            outputStatus: .inserted,
            pipelineSteps: ["stt:mock"]
        )
        manager.add(record1)
        manager.add(record2)

        // Search for "hello" — should return exactly 1
        let results = manager.search(query: "hello")
        #expect(results.count == 1, "Expected 1 result for 'hello', got \(results.count)")

        // Save and reload
        try manager.save()

        let manager2 = HistoryManager(directory: tempDir)
        manager2.load()

        #expect(manager2.records.count == 2,
                "Expected 2 records after reload, got \(manager2.records.count)")
    }
}
