import Foundation
import CryptoKit

// MARK: - Inner Result Types (same as legacy /v2/iat, used for the decoded `text` payload)

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

// MARK: - Spark IAT Response Frame Types (iat.xf-yun.com/v1)

struct SparkResponseFrame: Codable, Sendable {
    let header: SparkResponseHeader
    let payload: SparkResponsePayload?
}

struct SparkResponseHeader: Codable, Sendable {
    let code: Int
    let message: String?
    let sid: String?
    /// Session status: 0 = initial, 1 = ongoing, 2 = complete.
    let status: Int
}

struct SparkResponsePayload: Codable, Sendable {
    let result: SparkResponseResult?
}

struct SparkResponseResult: Codable, Sendable {
    /// Base64-encoded JSON payload. Decode then parse as `IFlytekResult`.
    let text: String
    let status: Int?
    let seq: Int?
}

// MARK: - Error Types

enum IFlytekError: LocalizedError, Sendable {
    case apiError(code: Int, message: String)
    case invalidConfiguration
    case connectionFailed
    case invalidResponsePayload

    var errorDescription: String? {
        switch self {
        case .apiError(let code, let message):
            return "iFlytek error \(code): \(message)"
        case .invalidConfiguration:
            return "iFlytek: invalid API configuration"
        case .connectionFailed:
            return "iFlytek: WebSocket connection failed"
        case .invalidResponsePayload:
            return "iFlytek: could not decode response payload"
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

// MARK: - iFlytek STT Adapter (Spark IAT — iat.xf-yun.com/v1)

/// STT adapter for iFlytek's Spark-backed streaming IAT endpoint.
/// Reference: https://www.xfyun.cn/doc/spark/spark_zh_iat.html
///
/// Differences from the legacy `iat-api.xfyun.cn/v2/iat` endpoint:
/// - Host `iat.xf-yun.com`, path `/v1`.
/// - Request schema is `{header, parameter, payload}` instead of
///   `{common, business, data}`.
/// - Audio params (sample_rate, channels, bit_depth, seq, status, audio)
///   live under `payload.audio` and need a `seq` that increments per frame.
/// - `parameter.iat.domain = "slm"` selects the large-model backend.
/// - Response text is double-encoded: `payload.result.text` is a base64
///   string whose contents are the JSON we used to read directly on /v2.
/// - The signature scheme is identical (HMAC-SHA256 with apiSecret), just
///   with the new host and `/v1` path in the signature origin.
final class IFlytekSTTAdapter: STTAdapter, @unchecked Sendable {
    private let appId: String
    private let apiKey: String
    private let apiSecret: String
    private let session: URLSession

    private static let host = "iat.xf-yun.com"
    private static let path = "/v1"

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
    /// Identical to the legacy scheme except the `host` and path inside
    /// `signature_origin`.
    static func buildAuthURL(appId: String, apiKey: String, apiSecret: String, date: Date = Date()) -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        dateFormatter.timeZone = TimeZone(identifier: "GMT")
        let dateString = dateFormatter.string(from: date)

        let signatureOrigin = "host: \(host)\ndate: \(dateString)\nGET \(path) HTTP/1.1"

        guard let secretData = apiSecret.data(using: .utf8),
              let messageData = signatureOrigin.data(using: .utf8) else {
            return nil
        }
        let key = SymmetricKey(data: secretData)
        let signature = HMAC<SHA256>.authenticationCode(for: messageData, using: key)
        let signatureBase64 = Data(signature).base64EncodedString()

        let authorizationOrigin = "api_key=\"\(apiKey)\", algorithm=\"hmac-sha256\", headers=\"host date request-line\", signature=\"\(signatureBase64)\""
        let authorizationBase64 = authorizationOrigin.data(using: .utf8)?.base64EncodedString() ?? ""

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

    // MARK: - Frame Builders

    /// Builds a send frame. `frameStatus` is the audio status:
    /// 0 = first, 1 = middle, 2 = last. The first frame also carries the
    /// `parameter` block; subsequent frames only carry `header` + `payload`.
    private func buildFrame(
        audioBase64: String,
        seq: Int,
        frameStatus: Int,
        lang: String
    ) -> [String: Any] {
        let audioObject: [String: Any] = [
            "encoding": "raw",
            "sample_rate": 16000,
            "channels": 1,
            "bit_depth": 16,
            "seq": seq,
            "status": frameStatus,
            "audio": audioBase64
        ]

        var frame: [String: Any] = [
            "header": [
                "app_id": self.appId,
                "status": frameStatus
            ],
            "payload": [
                "audio": audioObject
            ]
        ]

        if frameStatus == 0 {
            frame["parameter"] = [
                "iat": [
                    "domain": "slm",
                    "language": mapLanguage(lang),
                    "accent": "mandarin",
                    "eos": 3000,
                    "dwa": "wpgs",
                    "result": [
                        "encoding": "utf8",
                        "compress": "raw",
                        "format": "json"
                    ]
                ]
            ]
        }
        return frame
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

                Log.stt.info("Connecting to Spark IAT...")
                let webSocketTask = self.session.webSocketTask(with: url)
                webSocketTask.resume()

                var accumulator = IFlytekResultAccumulator()
                var previousText = ""

                // Receiver task — drains the socket until header.status == 2.
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

                // Stream audio chunks. seq starts at 1 and increments per frame.
                var seq = 1
                var isFirst = true
                var framesReceivedFromStream = 0

                for await audioChunk in audioStream {
                    framesReceivedFromStream += 1
                    let audioBase64 = audioChunk.base64EncodedString()
                    let frameStatus = isFirst ? 0 : 1
                    let frame = self.buildFrame(
                        audioBase64: audioBase64,
                        seq: seq,
                        frameStatus: frameStatus,
                        lang: lang
                    )
                    isFirst = false

                    if let jsonData = try? JSONSerialization.data(withJSONObject: frame),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        do {
                            try await webSocketTask.send(.string(jsonString))
                            if seq == 1 {
                                Log.stt.debug("First frame sent OK (spark/v1)")
                            }
                        } catch {
                            Log.stt.error("Send error at seq \(seq, privacy: .public): \(error, privacy: .public)")
                            break
                        }
                    }
                    seq += 1
                }

                DebugLog.write("[stt] audioStream drained: framesReceived=\(framesReceivedFromStream) lastSeq=\(seq - 1)")

                // Last frame (status=2, empty audio).
                let lastFrame = self.buildFrame(
                    audioBase64: "",
                    seq: seq,
                    frameStatus: 2,
                    lang: lang
                )
                if let jsonData = try? JSONSerialization.data(withJSONObject: lastFrame),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    try? await webSocketTask.send(.string(jsonString))
                }

                await receiveTask.value
                webSocketTask.cancel(with: .goingAway, reason: nil)
            }
        }
    }

    /// Returns true when header.status == 2 (session complete).
    private func processResponseData(
        _ data: Data,
        accumulator: inout IFlytekResultAccumulator,
        previousText: inout String,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) throws -> Bool {
        let frame = try JSONDecoder().decode(SparkResponseFrame.self, from: data)

        guard frame.header.code == 0 else {
            DebugLog.write("[stt] iFlytek error code=\(frame.header.code) msg=\(frame.header.message ?? "?")")
            throw IFlytekError.apiError(
                code: frame.header.code,
                message: frame.header.message ?? "Unknown error"
            )
        }

        // Decode the nested result.text (base64 → JSON → IFlytekResult).
        if let textBase64 = frame.payload?.result?.text,
           !textBase64.isEmpty,
           let innerData = Data(base64Encoded: textBase64) {
            let inner = try JSONDecoder().decode(IFlytekResult.self, from: innerData)
            let words = inner.ws ?? []
            let text = words.flatMap { $0.cw ?? [] }.map(\.w).joined()

            if let sn = inner.sn {
                accumulator.process(sn: sn, pgs: inner.pgs, rg: inner.rg, text: text)
            }

            let currentText = accumulator.currentText
            if currentText != previousText {
                continuation.yield(currentText)
                previousText = currentText
            }
        }

        if frame.header.status == 2 {
            continuation.finish()
            return true
        }
        return false
    }

    func transcribe(audio: Data, lang: String) async throws -> String {
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
