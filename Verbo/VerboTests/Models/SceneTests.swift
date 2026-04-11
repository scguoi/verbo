import Testing
import Foundation
@testable import Verbo

@Suite("Scene Tests")
struct SceneTests {

    @Test("Presets contains 3 scenes")
    func presetsCount() {
        #expect(Scene.presets.count == 3)
    }

    @Test("Presets contain dictate scene")
    func presetsDictate() {
        let dictate = Scene.presets.first { $0.id == "dictate" }
        #expect(dictate != nil)
        #expect(dictate?.name == "语音输入")
    }

    @Test("Presets contain polish scene")
    func presetsPolish() {
        let polish = Scene.presets.first { $0.id == "polish" }
        #expect(polish != nil)
        #expect(polish?.name == "润色输入")
    }

    @Test("Presets contain translate scene")
    func presetsTranslate() {
        let translate = Scene.presets.first { $0.id == "translate" }
        #expect(translate != nil)
        #expect(translate?.name == "中译英")
    }

    @Test("Dictate scene has 1 STT step")
    func dictatePipelineSteps() {
        let dictate = Scene.presets.first { $0.id == "dictate" }!
        #expect(dictate.pipeline.count == 1)
        #expect(dictate.pipeline[0].type == .stt)
        #expect(dictate.pipeline[0].provider == "iflytek")
        #expect(dictate.pipeline[0].lang == "zh")
    }

    @Test("Polish scene has STT + LLM steps")
    func polishPipelineSteps() {
        let polish = Scene.presets.first { $0.id == "polish" }!
        #expect(polish.pipeline.count == 2)
        #expect(polish.pipeline[0].type == .stt)
        #expect(polish.pipeline[1].type == .llm)
        #expect(polish.pipeline[1].provider == "openai")
    }

    @Test("Polish LLM step prompt contains {{input}}")
    func polishPromptContainsInput() {
        let polish = Scene.presets.first { $0.id == "polish" }!
        let llmStep = polish.pipeline.first { $0.type == .llm }!
        #expect(llmStep.prompt?.contains("{{input}}") == true)
    }

    @Test("Translate scene has STT + LLM steps")
    func translatePipelineSteps() {
        let translate = Scene.presets.first { $0.id == "translate" }!
        #expect(translate.pipeline.count == 2)
        #expect(translate.pipeline[0].type == .stt)
        #expect(translate.pipeline[1].type == .llm)
        #expect(translate.pipeline[1].provider == "openai")
    }

    @Test("Translate LLM step prompt contains {{input}}")
    func translatePromptContainsInput() {
        let translate = Scene.presets.first { $0.id == "translate" }!
        let llmStep = translate.pipeline.first { $0.type == .llm }!
        #expect(llmStep.prompt?.contains("{{input}}") == true)
    }

    @Test("Dictate hotkey is Alt+D")
    func dictateHotkey() {
        let dictate = Scene.presets.first { $0.id == "dictate" }!
        #expect(dictate.hotkey.toggleRecord == "Alt+D")
    }

    @Test("Polish hotkey is Alt+J")
    func polishHotkey() {
        let polish = Scene.presets.first { $0.id == "polish" }!
        #expect(polish.hotkey.toggleRecord == "Alt+J")
    }

    @Test("Translate hotkey is Alt+T")
    func translateHotkey() {
        let translate = Scene.presets.first { $0.id == "translate" }!
        #expect(translate.hotkey.toggleRecord == "Alt+T")
    }

    @Test("Scene JSON round-trip")
    func jsonRoundTrip() throws {
        let scenes = Scene.presets
        let encoder = JSONEncoder()
        let data = try encoder.encode(scenes)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode([Scene].self, from: data)
        #expect(decoded == scenes)
    }

    @Test("PipelineStep StepType raw values")
    func stepTypeRawValues() {
        #expect(PipelineStep.StepType.stt.rawValue == "stt")
        #expect(PipelineStep.StepType.llm.rawValue == "llm")
    }
}
