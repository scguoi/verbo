import Foundation

// MARK: - OpenAI Errors

enum OpenAIError: Error, Sendable {
    case httpError(statusCode: Int, body: String)
    case parseError
}

// MARK: - OpenAI SSE Parser

enum OpenAISSEParser {
    /// Parse "data: {JSON}" lines, extract choices[0].delta.content.
    /// Returns nil for "data: [DONE]", non-data lines, or parse failures.
    static func parseContentFromLine(_ line: String) -> String? {
        guard line.hasPrefix("data: ") else { return nil }
        let jsonString = String(line.dropFirst("data: ".count))
        guard jsonString != "[DONE]" else { return nil }
        guard let data = jsonString.data(using: .utf8) else { return nil }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let delta = first["delta"] as? [String: Any],
            let content = delta["content"] as? String
        else {
            return nil
        }
        return content
    }
}

// MARK: - OpenAI LLM Adapter

final class OpenAILLMAdapter: LLMAdapter, @unchecked Sendable {

    // MARK: - Properties

    let name: String = "openai"

    private let apiKey: String
    private let model: String
    private let baseUrl: String

    // MARK: - Init

    init(
        apiKey: String,
        model: String = "gpt-4o-mini",
        baseUrl: String = "https://api.openai.com/v1"
    ) {
        self.apiKey = apiKey
        self.model = model
        self.baseUrl = baseUrl
    }

    // MARK: - Request Body Builder

    static func buildRequestBody(model: String, prompt: String, stream: Bool) -> [String: Any] {
        [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "stream": stream
        ]
    }

    // MARK: - Complete (non-streaming)

    func complete(prompt: String) async throws -> String {
        let url = try makeURL(path: "/chat/completions")
        var request = makeRequest(url: url)

        let body = Self.buildRequestBody(model: model, prompt: prompt, stream: false)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw OpenAIError.parseError
        }

        return content
    }

    // MARK: - Complete Stream (SSE)

    func completeStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = try self.makeURL(path: "/chat/completions")
                    var request = self.makeRequest(url: url)

                    let body = Self.buildRequestBody(model: self.model, prompt: prompt, stream: true)
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        var errorBody = ""
                        for try await byte in bytes {
                            errorBody += String(bytes: [byte], encoding: .utf8) ?? ""
                        }
                        throw OpenAIError.httpError(statusCode: httpResponse.statusCode, body: errorBody)
                    }

                    var accumulated = ""
                    for try await line in bytes.lines {
                        if let delta = OpenAISSEParser.parseContentFromLine(line) {
                            accumulated += delta
                            continuation.yield(accumulated)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Helpers

    private func makeURL(path: String) throws -> URL {
        let urlString = baseUrl.hasSuffix("/")
            ? baseUrl.dropLast() + path
            : baseUrl + path
        guard let url = URL(string: String(urlString)) else {
            throw OpenAIError.parseError
        }
        return url
    }

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }
}
