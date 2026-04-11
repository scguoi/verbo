import Foundation
import CryptoKit

// MARK: - Response Types

struct IFlytekResponseFrame: Codable, Sendable {
    let code: Int
    let message: String?
    let data: IFlytekData?
    let sid: String?
}

struct IFlytekData: Codable, Sendable {
    let result: IFlytekResult?
    let status: Int?
}

struct IFlytekResult: Codable, Sendable {
    let ws: [IFlytekWord]?
    let sn: Int?
    let ls: Bool?
    let pgs: String?
    let rg: [Int]?
}

struct IFlytekWord: Codable, Sendable {
    let cw: [IFlytekChar]?
}

struct IFlytekChar: Codable, Sendable {
    let w: String
    let sc: Double?
}

// MARK: - Error Types

enum IFlytekError: LocalizedError, Sendable {
    case apiError(code: Int, message: String)
    case invalidConfiguration
    case connectionFailed

    var errorDescription: String? {
        switch self {
        case .apiError(let code, let message):
            return "iFlytek error \(code): \(message)"
        case .invalidConfiguration:
            return "iFlytek: invalid API configuration"
        case .connectionFailed:
            return "iFlytek: WebSocket connection failed"
        }
    }
}

// MARK: - Result Accumulator

/// Handles iFlytek's streaming text replacement (pgs: "apd" for append, "rpl" for replace).
struct IFlytekResultAccumulator: Sendable {
    private var sentences: [(sn: Int, text: String)] = []

    var currentText: String {
        sentences.map(\.text).joined()
    }

    /// Processes a result frame from iFlytek.
    /// - Parameters:
    ///   - sn: Sentence number (sequence number)
    ///   - pgs: Page status — "apd" for append, "rpl" for replace
    ///   - rg: Range [begin, end] of sentence numbers to replace (only used when pgs == "rpl")
    ///   - text: The recognized text for this frame
    mutating func process(sn: Int, pgs: String?, rg: [Int]?, text: String) {
        if pgs == "rpl", let rg, rg.count == 2 {
            let rgBegin = rg[0]
            let rgEnd = rg[1]
            sentences.removeAll { $0.sn >= rgBegin && $0.sn <= rgEnd }
        }
        sentences.append((sn: sn, text: text))
        sentences.sort { $0.sn < $1.sn }
    }

    mutating func reset() {
        sentences = []
    }
}

// MARK: - iFlytek STT Adapter

/// STT adapter for iFlytek (科大讯飞) using WebSocket streaming API.
/// Reference: https://www.xfyun.cn/doc/asr/voicedictation/API.html
final class IFlytekSTTAdapter: STTAdapter, @unchecked Sendable {
    private let appId: String
    private let apiKey: String
    private let apiSecret: String
    private let session: URLSession

    private static let host = "iat-api.xfyun.cn"
    private static let path = "/v2/iat"

    var name: String { "iFlytek" }
    var supportsStreaming: Bool { true }

    init(appId: String, apiKey: String, apiSecret: String, session: URLSession = .shared) {
        self.appId = appId
        self.apiKey = apiKey
        self.apiSecret = apiSecret
        self.session = session
    }

    // MARK: - Auth URL Builder

    /// Builds the authenticated WSS URL using HMAC-SHA256 signature.
    static func buildAuthURL(appId: String, apiKey: String, apiSecret: String, date: Date = Date()) -> URL? {
        // Format date as RFC1123
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        dateFormatter.timeZone = TimeZone(identifier: "GMT")
        let dateString = dateFormatter.string(from: date)

        // Build signature origin string
        let signatureOrigin = "host: \(host)\ndate: \(dateString)\nGET \(path) HTTP/1.1"

        // HMAC-SHA256 sign with apiSecret
        guard let secretData = apiSecret.data(using: .utf8),
              let messageData = signatureOrigin.data(using: .utf8) else {
            return nil
        }
        let key = SymmetricKey(data: secretData)
        let signature = HMAC<SHA256>.authenticationCode(for: messageData, using: key)
        let signatureBase64 = Data(signature).base64EncodedString()

        // Build authorization header value
        let authorizationOrigin = "api_key=\"\(apiKey)\", algorithm=\"hmac-sha256\", headers=\"host date request-line\", signature=\"\(signatureBase64)\""
        let authorizationBase64 = authorizationOrigin.data(using: .utf8)?.base64EncodedString() ?? ""

        // Build URL with manually percent-encoded query params.
        // URLComponents.queryItems would double-encode base64 chars (+, /, =),
        // causing iFlytek auth to fail intermittently.
        let dateEncoded = dateString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dateString
        let authEncoded = authorizationBase64.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? authorizationBase64
        let urlString = "wss://\(host)\(path)?authorization=\(authEncoded)&date=\(dateEncoded)&host=\(host)"
        return URL(string: urlString)
    }

    // MARK: - Language Mapping

    private func mapLanguage(_ lang: String) -> String {
        switch lang {
        case "zh": return "zh_cn"
        case "en": return "en_us"
        default: return lang
        }
    }

    // MARK: - STTAdapter Implementation

    func transcribeStream(
        audioStream: AsyncStream<Data>,
        lang: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let url = IFlytekSTTAdapter.buildAuthURL(
                    appId: self.appId,
                    apiKey: self.apiKey,
                    apiSecret: self.apiSecret
                ) else {
                    Log.stt.error("Failed to build auth URL")
                    continuation.finish(throwing: IFlytekError.invalidConfiguration)
                    return
                }

                Log.stt.info("Connecting...")
                let webSocketTask = self.session.webSocketTask(with: url)
                webSocketTask.resume()

                var accumulator = IFlytekResultAccumulator()
                var isFirst = true
                var previousText = ""
                var frameIndex = 0

                // Task to receive WebSocket messages
                let receiveTask = Task {
                    while !Task.isCancelled {
                        do {
                            let message = try await webSocketTask.receive()
                            let responseData: Data
                            switch message {
                            case .string(let text):
                                guard let data = text.data(using: .utf8) else { continue }
                                responseData = data
                            case .data(let data):
                                responseData = data
                            @unknown default:
                                continue
                            }

                            let isComplete = try processResponseData(
                                responseData,
                                accumulator: &accumulator,
                                previousText: &previousText,
                                continuation: continuation
                            )
                            if isComplete { return }

                        } catch is CancellationError {
                            Log.stt.debug("Receive cancelled (normal)")
                            continuation.finish()
                            return
                        } catch let error as URLError where error.code == .cancelled {
                            Log.stt.debug("Receive cancelled (normal)")
                            continuation.finish()
                            return
                        } catch {
                            Log.stt.error("Receive error: \(error, privacy: .public)")
                            continuation.finish(throwing: error)
                            return
                        }
                    }
                }

                // Send audio frames
                for await audioChunk in audioStream {
                    let frame: [String: Any]
                    let audioBase64 = audioChunk.base64EncodedString()

                    if isFirst {
                        frame = [
                            "common": ["app_id": self.appId],
                            "business": [
                                "language": self.mapLanguage(lang),
                                "domain": "iat",
                                "accent": "mandarin",
                                "dwa": "wpgs",
                                "ptt": 1,
                                "vad_eos": 3000
                            ],
                            "data": [
                                "status": 0,
                                "format": "audio/L16;rate=16000",
                                "encoding": "raw",
                                "audio": audioBase64
                            ]
                        ]
                        isFirst = false
                    } else {
                        frame = [
                            "data": [
                                "status": 1,
                                "format": "audio/L16;rate=16000",
                                "encoding": "raw",
                                "audio": audioBase64
                            ]
                        ]
                    }

                    if let jsonData = try? JSONSerialization.data(withJSONObject: frame),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        do {
                            try await webSocketTask.send(.string(jsonString))
                            if frameIndex == 0 {
                                Log.stt.debug("First frame sent OK")
                            }
                        } catch {
                            Log.stt.error("Send error at frame \(frameIndex, privacy: .public): \(error, privacy: .public)")
                            break
                        }
                    }
                    frameIndex += 1
                }

                // Send last frame (status=2, empty audio)
                let lastFrame: [String: Any] = [
                    "data": [
                        "status": 2,
                        "format": "audio/L16;rate=16000",
                        "encoding": "raw",
                        "audio": ""
                    ]
                ]
                if let jsonData = try? JSONSerialization.data(withJSONObject: lastFrame),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    try? await webSocketTask.send(.string(jsonString))
                }

                // Wait for recognition to complete
                await receiveTask.value
                webSocketTask.cancel(with: .goingAway, reason: nil)
            }
        }
    }

    /// Returns true if recognition is complete (status == 2)
    private func processResponseData(
        _ data: Data,
        accumulator: inout IFlytekResultAccumulator,
        previousText: inout String,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) throws -> Bool {
        let frame = try JSONDecoder().decode(IFlytekResponseFrame.self, from: data)

        guard frame.code == 0 else {
            throw IFlytekError.apiError(
                code: frame.code,
                message: frame.message ?? "Unknown error"
            )
        }

        let dataStatus = frame.data?.status ?? 0

        if let result = frame.data?.result {
            let words = result.ws ?? []
            let text = words.flatMap { $0.cw ?? [] }.map(\.w).joined()

            if let sn = result.sn {
                accumulator.process(sn: sn, pgs: result.pgs, rg: result.rg, text: text)
            }

            let currentText = accumulator.currentText
            if currentText != previousText {
                continuation.yield(currentText)
                previousText = currentText
            }
        }

        if dataStatus == 2 {
            continuation.finish()
            return true
        }
        return false
    }

    func transcribe(audio: Data, lang: String) async throws -> String {
        // Wrap single audio buffer in AsyncStream for transcribeStream
        let stream = AsyncStream<Data> { continuation in
            continuation.yield(audio)
            continuation.finish()
        }

        var finalText = ""
        for try await text in transcribeStream(audioStream: stream, lang: lang) {
            finalText = text
        }
        return finalText
    }
}
