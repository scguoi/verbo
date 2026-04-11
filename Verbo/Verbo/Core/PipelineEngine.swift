import Foundation

// MARK: - PipelineEngine

actor PipelineEngine {

    // MARK: - Template Resolution

    static func resolveTemplate(_ template: String, input: String) -> String {
        template.replacingOccurrences(of: "{{input}}", with: input)
    }

    // MARK: - Execute

    func execute(
        steps: [PipelineStep],
        audioStream: AsyncStream<Data>,
        getSTT: @escaping @Sendable (String) -> (any STTAdapter)?,
        getLLM: @escaping @Sendable (String) -> (any LLMAdapter)?
    ) -> AsyncThrowingStream<PipelineState, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var currentInput = ""
                var sttSource: String? = nil

                do {
                    for step in steps {
                        switch step.type {
                        case .stt:
                            guard let adapter = getSTT(step.provider) else {
                                throw PipelineError.adapterNotFound(provider: step.provider, type: "STT")
                            }
                            let lang = step.lang ?? "zh"
                            continuation.yield(.transcribing(partial: ""))

                            if adapter.supportsStreaming {
                                var lastPartial = ""
                                let stream = adapter.transcribeStream(audioStream: audioStream, lang: lang)
                                for try await partial in stream {
                                    lastPartial = partial
                                    continuation.yield(.transcribing(partial: partial))
                                }
                                currentInput = lastPartial
                            } else {
                                var audioData = Data()
                                for await chunk in audioStream {
                                    audioData.append(chunk)
                                }
                                currentInput = try await adapter.transcribe(audio: audioData, lang: lang)
                            }
                            sttSource = currentInput

                        case .llm:
                            guard let adapter = getLLM(step.provider) else {
                                throw PipelineError.adapterNotFound(provider: step.provider, type: "LLM")
                            }
                            let prompt = PipelineEngine.resolveTemplate(
                                step.prompt ?? "{{input}}",
                                input: currentInput
                            )
                            continuation.yield(.processing(source: currentInput, partial: ""))

                            var lastPartial = ""
                            let stream = adapter.completeStream(prompt: prompt)
                            for try await partial in stream {
                                lastPartial = partial
                                continuation.yield(.processing(source: currentInput, partial: partial))
                            }
                            currentInput = lastPartial
                        }
                    }

                    continuation.yield(.done(result: currentInput, source: sttSource))
                    continuation.finish()
                } catch is CancellationError {
                    // Task was cancelled (e.g. user stopped recording), not a real error
                    continuation.finish()
                } catch {
                    let message: String
                    if let urlError = error as? URLError {
                        message = "Network error: \(urlError.localizedDescription) (code: \(urlError.code.rawValue))"
                    } else {
                        message = error.localizedDescription
                    }
                    continuation.yield(.error(message: message))
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - PipelineError

enum PipelineError: LocalizedError {
    case adapterNotFound(provider: String, type: String)

    var errorDescription: String? {
        switch self {
        case .adapterNotFound(let provider, let type):
            return "\(type) adapter not found for provider: \(provider)"
        }
    }
}
