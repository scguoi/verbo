import Testing
import Foundation
@testable import Verbo

// MARK: - Auth URL Tests

@Suite("IFlytekSTTAdapter Auth URL")
struct IFlytekSTTAdapterAuthURLTests {
    @Test("Auth URL contains required query parameters")
    func authURLContainsRequiredParams() throws {
        let url = IFlytekSTTAdapter.buildAuthURL(
            appId: "testAppId",
            apiKey: "testApiKey",
            apiSecret: "testApiSecret"
        )
        #expect(url != nil, "buildAuthURL should return a valid URL")
        guard let url else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        #expect(components?.host == "iat-api.xfyun.cn")
        #expect(components?.path == "/v2/iat")

        let queryItems = components?.queryItems ?? []
        let paramNames = Set(queryItems.map(\.name))
        #expect(paramNames.contains("authorization"))
        #expect(paramNames.contains("date"))
        #expect(paramNames.contains("host"))
        #expect(url.scheme == "wss")
    }
}

// MARK: - Response Frame Parsing Tests

@Suite("IFlytekResponseFrame Parsing")
struct IFlytekResponseFrameParsingTests {
    @Test("Parse single response frame with Chinese text")
    func parseSingleResponseFrame() throws {
        let json = """
        {
            "code": 0,
            "message": "success",
            "sid": "iat000123",
            "data": {
                "status": 1,
                "result": {
                    "sn": 1,
                    "pgs": "apd",
                    "ls": false,
                    "ws": [
                        {
                            "cw": [
                                { "w": "你", "sc": 0.0 },
                                { "w": "好", "sc": 0.0 }
                            ]
                        }
                    ]
                }
            }
        }
        """
        let data = try #require(json.data(using: .utf8))
        let frame = try JSONDecoder().decode(IFlytekResponseFrame.self, from: data)

        #expect(frame.code == 0)
        #expect(frame.sid == "iat000123")
        #expect(frame.data?.result?.sn == 1)
        #expect(frame.data?.result?.pgs == "apd")
        #expect(frame.data?.result?.ls == false)

        let words = frame.data?.result?.ws ?? []
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
