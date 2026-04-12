import Testing
import Foundation
@testable import Verbo

@Suite("HistoryRecord Tests")
struct HistoryRecordTests {

    func makeRecord(
        originalText: String = "原始文本",
        finalText: String = "最终文本"
    ) -> HistoryRecord {
        HistoryRecord(
            id: UUID(),
            timestamp: Date(),
            sceneId: "dictate",
            sceneName: "语音输入",
            originalText: originalText,
            finalText: finalText,
            outputStatus: .inserted,
            pipelineSteps: ["stt:iflytek"]
        )
    }

    @Test("HistoryRecord can be created")
    func canBeCreated() {
        let record = makeRecord()
        #expect(record.sceneId == "dictate")
        #expect(record.sceneName == "语音输入")
        #expect(record.originalText == "原始文本")
        #expect(record.finalText == "最终文本")
        #expect(record.outputStatus == .inserted)
        #expect(record.pipelineSteps == ["stt:iflytek"])
    }

    @Test("hasLLMProcessing is true when original != final")
    func hasLLMProcessingTrue() {
        let record = makeRecord(originalText: "original", finalText: "polished")
        #expect(record.hasLLMProcessing == true)
    }

    @Test("hasLLMProcessing is false when original == final")
    func hasLLMProcessingFalse() {
        let record = makeRecord(originalText: "same text", finalText: "same text")
        #expect(record.hasLLMProcessing == false)
    }

    @Test("HistoryRecord JSON round-trip")
    func jsonRoundTrip() throws {
        // Use secondsSince1970 to avoid sub-second precision loss with iso8601
        let truncatedDate = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
        let original = HistoryRecord(
            id: UUID(),
            timestamp: truncatedDate,
            sceneId: "dictate",
            sceneName: "语音输入",
            originalText: "原始文本",
            finalText: "最终文本",
            outputStatus: .inserted,
            pipelineSteps: ["stt:iflytek"]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(HistoryRecord.self, from: data)
        #expect(decoded == original)
    }

    @Test("OutputStatus raw values")
    func outputStatusRawValues() {
        #expect(HistoryRecord.OutputStatus.inserted.rawValue == "inserted")
        #expect(HistoryRecord.OutputStatus.copied.rawValue == "copied")
        #expect(HistoryRecord.OutputStatus.failed.rawValue == "failed")
    }

    @Test("HistoryRecord id is unique per instance")
    func uniqueIds() {
        let record1 = makeRecord()
        let record2 = makeRecord()
        #expect(record1.id != record2.id)
    }

    @Test("HistoryRecord with copied status")
    func copiedStatus() {
        let record = HistoryRecord(
            id: UUID(),
            timestamp: Date(),
            sceneId: "polish",
            sceneName: "润色输入",
            originalText: "text",
            finalText: "polished text",
            outputStatus: .copied,
            pipelineSteps: ["stt:iflytek", "llm:openai"]
        )
        #expect(record.outputStatus == .copied)
    }

    @Test("HistoryRecord decodes legacy JSON without endToEndLatencyMs field")
    func legacyJSONDecode() throws {
        let legacyJSON = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "timestamp": 1700000000,
            "sceneId": "dictate",
            "sceneName": "语音输入",
            "originalText": "hi",
            "finalText": "hi",
            "outputStatus": "inserted",
            "pipelineSteps": ["stt:iflytek"]
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let record = try decoder.decode(HistoryRecord.self, from: legacyJSON)
        #expect(record.endToEndLatencyMs == nil)
        #expect(record.finalText == "hi")
    }

    @Test("HistoryRecord with latency round-trips through JSON")
    func latencyRoundTrip() throws {
        let record = HistoryRecord(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 1700000000),
            sceneId: "dictate",
            sceneName: "语音输入",
            originalText: "hi",
            finalText: "hi",
            outputStatus: .inserted,
            pipelineSteps: ["stt:iflytek"],
            endToEndLatencyMs: 1234
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(record)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(HistoryRecord.self, from: data)
        #expect(decoded.endToEndLatencyMs == 1234)
    }

    @Test("HistoryRecord with failed status")
    func failedStatus() {
        let record = HistoryRecord(
            id: UUID(),
            timestamp: Date(),
            sceneId: "dictate",
            sceneName: "语音输入",
            originalText: "text",
            finalText: "text",
            outputStatus: .failed,
            pipelineSteps: ["stt:iflytek"]
        )
        #expect(record.outputStatus == .failed)
    }
}
