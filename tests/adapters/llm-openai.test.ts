import { describe, it, expect, vi, beforeEach } from 'vitest'
import { createOpenAIAdapter } from '../../src/adapters/llm/openai'
import type { LLMAdapter, LLMOptions } from '../../src/adapters/llm/types'

const DEFAULT_CONFIG = {
  apiKey: 'test-api-key',
  model: 'gpt-4',
  baseUrl: 'https://api.openai.com/v1',
} as const

function makeSuccessResponse(content: string): Response {
  return {
    ok: true,
    status: 200,
    json: async () => ({
      choices: [{ message: { content } }],
    }),
  } as unknown as Response
}

function makeErrorResponse(status: number, body: string): Response {
  return {
    ok: false,
    status,
    text: async () => body,
  } as unknown as Response
}

function makeSSEStream(chunks: string[]): ReadableStream<Uint8Array> {
  const encoder = new TextEncoder()
  return new ReadableStream({
    start(controller) {
      for (const chunk of chunks) {
        controller.enqueue(encoder.encode(chunk))
      }
      controller.close()
    },
  })
}

function makeStreamResponse(chunks: string[]): Response {
  return {
    ok: true,
    status: 200,
    body: makeSSEStream(chunks),
  } as unknown as Response
}

describe('OpenAI LLM adapter', () => {
  let fetchMock: ReturnType<typeof vi.fn>

  beforeEach(() => {
    fetchMock = vi.fn()
    vi.stubGlobal('fetch', fetchMock)
  })

  describe('interface conformance', () => {
    it('should have correct name', () => {
      const adapter = createOpenAIAdapter(DEFAULT_CONFIG)
      expect(adapter.name).toBe('openai')
    })

    it('should have complete method', () => {
      const adapter = createOpenAIAdapter(DEFAULT_CONFIG)
      expect(typeof adapter.complete).toBe('function')
    })

    it('should have completeStream method', () => {
      const adapter = createOpenAIAdapter(DEFAULT_CONFIG)
      expect(typeof adapter.completeStream).toBe('function')
    })

    it('should conform to LLMAdapter interface', () => {
      const adapter: LLMAdapter = createOpenAIAdapter(DEFAULT_CONFIG)
      expect(adapter.name).toBe('openai')
      expect(typeof adapter.complete).toBe('function')
    })

    it('complete() should accept LLMOptions and return Promise<string>', async () => {
      fetchMock.mockResolvedValue(makeSuccessResponse('hello'))
      const adapter = createOpenAIAdapter(DEFAULT_CONFIG)
      const options: LLMOptions = { prompt: 'test' }
      const result = await adapter.complete(options)
      expect(typeof result).toBe('string')
    })
  })

  describe('complete()', () => {
    it('should use correct URL with baseUrl', async () => {
      fetchMock.mockResolvedValue(makeSuccessResponse('response'))
      const adapter = createOpenAIAdapter(DEFAULT_CONFIG)

      await adapter.complete({ prompt: 'hello' })

      expect(fetchMock).toHaveBeenCalledWith(
        'https://api.openai.com/v1/chat/completions',
        expect.any(Object),
      )
    })

    it('should handle baseUrl with trailing slash', async () => {
      fetchMock.mockResolvedValue(makeSuccessResponse('response'))
      const adapter = createOpenAIAdapter({
        ...DEFAULT_CONFIG,
        baseUrl: 'https://api.openai.com/v1/',
      })

      await adapter.complete({ prompt: 'hello' })

      expect(fetchMock).toHaveBeenCalledWith(
        'https://api.openai.com/v1/chat/completions',
        expect.any(Object),
      )
    })

    it('should send correct Authorization header', async () => {
      fetchMock.mockResolvedValue(makeSuccessResponse('response'))
      const adapter = createOpenAIAdapter(DEFAULT_CONFIG)

      await adapter.complete({ prompt: 'hello' })

      const callArgs = fetchMock.mock.calls[0][1]
      expect(callArgs.headers.Authorization).toBe('Bearer test-api-key')
    })

    it('should send correct body format with stream:false', async () => {
      fetchMock.mockResolvedValue(makeSuccessResponse('response'))
      const adapter = createOpenAIAdapter(DEFAULT_CONFIG)

      await adapter.complete({ prompt: 'hello world' })

      const callArgs = fetchMock.mock.calls[0][1]
      const body = JSON.parse(callArgs.body)
      expect(body).toEqual({
        model: 'gpt-4',
        messages: [{ role: 'user', content: 'hello world' }],
        stream: false,
      })
    })

    it('should use options.model when provided', async () => {
      fetchMock.mockResolvedValue(makeSuccessResponse('response'))
      const adapter = createOpenAIAdapter(DEFAULT_CONFIG)

      await adapter.complete({ prompt: 'hello', model: 'gpt-3.5-turbo' })

      const callArgs = fetchMock.mock.calls[0][1]
      const body = JSON.parse(callArgs.body)
      expect(body.model).toBe('gpt-3.5-turbo')
    })

    it('should return content from response', async () => {
      fetchMock.mockResolvedValue(makeSuccessResponse('The answer is 42'))
      const adapter = createOpenAIAdapter(DEFAULT_CONFIG)

      const result = await adapter.complete({ prompt: 'what is the answer?' })

      expect(result).toBe('The answer is 42')
    })

    it('should throw on error responses with status and body', async () => {
      fetchMock.mockResolvedValue(makeErrorResponse(401, 'Unauthorized'))
      const adapter = createOpenAIAdapter(DEFAULT_CONFIG)

      await expect(adapter.complete({ prompt: 'hello' })).rejects.toThrow(
        'OpenAI API error 401: Unauthorized',
      )
    })

    it('should throw on 500 error', async () => {
      fetchMock.mockResolvedValue(
        makeErrorResponse(500, '{"error":"Internal Server Error"}'),
      )
      const adapter = createOpenAIAdapter(DEFAULT_CONFIG)

      await expect(adapter.complete({ prompt: 'hello' })).rejects.toThrow(
        'OpenAI API error 500',
      )
    })
  })

  describe('completeStream()', () => {
    it('should send stream:true in body', async () => {
      const sseChunks = [
        'data: {"choices":[{"delta":{"content":"Hi"}}]}\n\n',
        'data: [DONE]\n\n',
      ]
      fetchMock.mockResolvedValue(makeStreamResponse(sseChunks))
      const adapter = createOpenAIAdapter(DEFAULT_CONFIG)

      await adapter.completeStream!({ prompt: 'hello' }, () => {})

      const callArgs = fetchMock.mock.calls[0][1]
      const body = JSON.parse(callArgs.body)
      expect(body.stream).toBe(true)
    })

    it('should parse SSE data lines and extract content', async () => {
      const sseChunks = [
        'data: {"choices":[{"delta":{"content":"Hello"}}]}\n\n',
        'data: {"choices":[{"delta":{"content":" world"}}]}\n\n',
        'data: [DONE]\n\n',
      ]
      fetchMock.mockResolvedValue(makeStreamResponse(sseChunks))
      const adapter = createOpenAIAdapter(DEFAULT_CONFIG)

      const result = await adapter.completeStream!({ prompt: 'hi' }, () => {})

      expect(result).toBe('Hello world')
    })

    it('should handle [DONE] marker', async () => {
      const sseChunks = [
        'data: {"choices":[{"delta":{"content":"done"}}]}\n\n',
        'data: [DONE]\n\n',
      ]
      fetchMock.mockResolvedValue(makeStreamResponse(sseChunks))
      const adapter = createOpenAIAdapter(DEFAULT_CONFIG)

      const result = await adapter.completeStream!({ prompt: 'hi' }, () => {})

      expect(result).toBe('done')
    })

    it('should call onChunk with accumulated text', async () => {
      const sseChunks = [
        'data: {"choices":[{"delta":{"content":"Hello"}}]}\n\n',
        'data: {"choices":[{"delta":{"content":" world"}}]}\n\n',
        'data: [DONE]\n\n',
      ]
      fetchMock.mockResolvedValue(makeStreamResponse(sseChunks))
      const adapter = createOpenAIAdapter(DEFAULT_CONFIG)
      const onChunk = vi.fn()

      await adapter.completeStream!({ prompt: 'hi' }, onChunk)

      expect(onChunk).toHaveBeenCalledWith('Hello')
      expect(onChunk).toHaveBeenCalledWith('Hello world')
    })

    it('should throw on error responses', async () => {
      fetchMock.mockResolvedValue(makeErrorResponse(429, 'Rate limited'))
      const adapter = createOpenAIAdapter(DEFAULT_CONFIG)

      await expect(
        adapter.completeStream!({ prompt: 'hello' }, () => {}),
      ).rejects.toThrow('OpenAI API error 429: Rate limited')
    })

    it('should skip non-data lines', async () => {
      const sseChunks = [
        ': comment line\n',
        'data: {"choices":[{"delta":{"content":"ok"}}]}\n\n',
        '\n',
        'data: [DONE]\n\n',
      ]
      fetchMock.mockResolvedValue(makeStreamResponse(sseChunks))
      const adapter = createOpenAIAdapter(DEFAULT_CONFIG)

      const result = await adapter.completeStream!({ prompt: 'hi' }, () => {})

      expect(result).toBe('ok')
    })

    it('should handle chunks split across boundaries', async () => {
      const sseChunks = [
        'data: {"choices":[{"delta":{"content":"He',
        'llo"}}]}\ndata: {"choices":[{"delta":{"content":" world"}}]}\n\ndata: [DONE]\n\n',
      ]
      fetchMock.mockResolvedValue(makeStreamResponse(sseChunks))
      const adapter = createOpenAIAdapter(DEFAULT_CONFIG)

      const result = await adapter.completeStream!({ prompt: 'hi' }, () => {})

      expect(result).toBe('Hello world')
    })
  })
})
