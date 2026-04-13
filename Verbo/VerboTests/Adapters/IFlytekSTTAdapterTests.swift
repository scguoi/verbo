import Testing
import Foundation
@testable import Verbo

// MARK: - Auth URL Tests

@Suite("IFlytekSTTAdapter Auth URL")
struct IFlytekSTTAdapterAuthURLTests {
    @Test("Auth URL points to Spark IAT endpoint with required query params")
    func authURLContainsRequiredParams() throws {
        let url = IFlytekSTTAdapter.buildAuthURL(
            appId: "testAppId",
            apiKey: "testApiKey",
            apiSecret: "testApiSecret"
        )
        #expect(url != nil, "buildAuthURL should return a valid URL")
        guard let url else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        #expect(components?.host == "iat.xf-yun.com")
        #expect(components?.path == "/v1")

        let queryItems = components?.queryItems ?? []
        let paramNames = Set(queryItems.map(\.name))
        #expect(paramNames.contains("authorization"))
        #expect(paramNames.contains("date"))
        #expect(paramNames.contains("host"))
        #expect(url.scheme == "wss")
    }
}

// MARK: - Response Frame Parsing Tests

@Suite("SparkResponseFrame Parsing")
struct SparkResponseFrameParsingTests {
    @Test("Outer envelope decodes and inner base64 text decodes to IFlytekResult")
    func parseSparkResponseFrame() throws {
        // Inner payload — what the caller would see after base64-decoding
        // `payload.result.text`. Same shape as the legacy /v2/iat result.
        let innerJSON = """
        {"sn":1,"ls":false,"pgs":"apd","ws":[{"cw":[{"w":"你","sc":0},{"w":"好","sc":0}]}]}
        """
        let innerBase64 = Data(innerJSON.utf8).base64EncodedString()

        let outerJSON = """
        {
            "header": {
                "code": 0,
                "message": "success",
                "sid": "iat000123",
                "status": 1
            },
            "payload": {
                "result": {
                    "encoding": "utf8",
                    "compress": "raw",
                    "format": "json",
                    "seq": 2,
                    "status": 1,
                    "text": "\(innerBase64)"
                }
            }
        }
        """
        let outerData = try #require(outerJSON.data(using: .utf8))
        let frame = try JSONDecoder().decode(SparkResponseFrame.self, from: outerData)

        #expect(frame.header.code == 0)
        #expect(frame.header.sid == "iat000123")
        #expect(frame.header.status == 1)

        // Decode the inner base64 payload.
        let textB64 = try #require(frame.payload?.result?.text)
        let innerData = try #require(Data(base64Encoded: textB64))
        let inner = try JSONDecoder().decode(IFlytekResult.self, from: innerData)

        #expect(inner.sn == 1)
        #expect(inner.pgs == "apd")
        #expect(inner.ls == false)

        let words = inner.ws ?? []
        let text = words.flatMap { $0.cw ?? [] }.map(\.w).joined()
        #expect(text == "你好")
    }
}

// MARK: - Accumulator Tests

@Suite("IFlytekResultAccumulator")
struct IFlytekResultAccumulatorTests {
    @Test("Append mode: two sentences concatenate correctly")
    func appendModeTwoSentences() {
        var accumulator = IFlytekResultAccumulator()
        accumulator.process(sn: 1, pgs: "apd", rg: nil, text: "你好")
        accumulator.process(sn: 2, pgs: "apd", rg: nil, text: "世界")
        #expect(accumulator.currentText == "你好世界")
    }

    @Test("Replace mode: rpl replaces specified range")
    func replaceModeBasic() {
        var accumulator = IFlytekResultAccumulator()
        accumulator.process(sn: 1, pgs: "apd", rg: nil, text: "你好")
        accumulator.process(sn: 2, pgs: "apd", rg: nil, text: "世界")
        // Replace sn 1-2 with a corrected version
        accumulator.process(sn: 3, pgs: "rpl", rg: [1, 2], text: "你好世界！")
        #expect(accumulator.currentText == "你好世界！")
    }

    @Test("Replace mode: multiple replaces with subsequent append")
    func replaceModeMultipleReplaces() {
        var accumulator = IFlytekResultAccumulator()
        accumulator.process(sn: 1, pgs: "apd", rg: nil, text: "今天")
        accumulator.process(sn: 2, pgs: "apd", rg: nil, text: "天气")
        // First replace: sn 1-2 replaced
        accumulator.process(sn: 3, pgs: "rpl", rg: [1, 2], text: "今天天气")
        // Append: sn 4
        accumulator.process(sn: 4, pgs: "apd", rg: nil, text: "很好")
        #expect(accumulator.currentText == "今天天气很好")
    }

    @Test("Reset clears all accumulated text")
    func resetClearsText() {
        var accumulator = IFlytekResultAccumulator()
        accumulator.process(sn: 1, pgs: "apd", rg: nil, text: "你好")
        accumulator.reset()
        #expect(accumulator.currentText == "")
    }
}
