import { describe, it, expect, vi, beforeEach } from 'vitest'
import { createAudioRecorder } from './recorder'
import type { AudioRecorder } from './recorder'

// ---------------------------------------------------------------------------
// Mock helpers
// ---------------------------------------------------------------------------

function createMockMediaStream(): MediaStream {
  const track = {
    stop: vi.fn(),
    kind: 'audio',
    id: 'mock-track',
  } as unknown as MediaStreamTrack

  return {
    getTracks: () => [track],
    getAudioTracks: () => [track],
  } as unknown as MediaStream
}

type DataAvailableHandler = (event: BlobEvent) => void
type StopHandler = (event: Event) => void

interface MockMediaRecorder {
  start: ReturnType<typeof vi.fn>
  stop: ReturnType<typeof vi.fn>
  state: string
  ondataavailable: DataAvailableHandler | null
  onstop: StopHandler | null
  _fireDataAvailable: (data: ArrayBuffer) => Promise<void>
  _fireStop: () => void
}

function createMockMediaRecorder(): MockMediaRecorder {
  const mock: MockMediaRecorder = {
    start: vi.fn(),
    stop: vi.fn(),
    state: 'inactive',
    ondataavailable: null,
    onstop: null,
    _fireDataAvailable: async (data: ArrayBuffer) => {
      const fakeBlob = {
        size: data.byteLength,
        arrayBuffer: () => Promise.resolve(data),
      }
      if (mock.ondataavailable) {
        mock.ondataavailable({ data: fakeBlob, type: 'dataavailable' } as unknown as BlobEvent)
      }
      // Let the arrayBuffer() promise resolve
      await new Promise((r) => setTimeout(r, 0))
    },
    _fireStop: () => {
      mock.state = 'inactive'
      if (mock.onstop) {
        mock.onstop(new Event('stop'))
      }
    },
  }

  mock.start.mockImplementation(() => {
    mock.state = 'recording'
  })

  mock.stop.mockImplementation(() => {
    mock._fireStop()
  })

  return mock
}

// ---------------------------------------------------------------------------
// Test setup
// ---------------------------------------------------------------------------

let mockRecorderInstance: MockMediaRecorder

beforeEach(() => {
  mockRecorderInstance = createMockMediaRecorder()

  // Mock navigator.mediaDevices.getUserMedia
  Object.defineProperty(globalThis, 'navigator', {
    value: {
      mediaDevices: {
        getUserMedia: vi.fn().mockResolvedValue(createMockMediaStream()),
      },
    },
    writable: true,
    configurable: true,
  })

  // Mock MediaRecorder constructor
  vi.stubGlobal(
    'MediaRecorder',
    vi.fn(() => mockRecorderInstance),
  )
})

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('AudioRecorder', () => {
  describe('interface conformance', () => {
    it('should return an object with start, stop, and isRecording methods', () => {
      const recorder: AudioRecorder = createAudioRecorder()
      expect(typeof recorder.start).toBe('function')
      expect(typeof recorder.stop).toBe('function')
      expect(typeof recorder.isRecording).toBe('function')
    })

    it('should have isRecording() return false initially', () => {
      const recorder = createAudioRecorder()
      expect(recorder.isRecording()).toBe(false)
    })
  })

  describe('state transitions', () => {
    it('should report isRecording() as true after start()', async () => {
      const recorder = createAudioRecorder()
      await recorder.start()
      expect(recorder.isRecording()).toBe(true)
    })

    it('should report isRecording() as false after stop()', async () => {
      const recorder = createAudioRecorder()
      await recorder.start()
      expect(recorder.isRecording()).toBe(true)

      await recorder.stop()
      expect(recorder.isRecording()).toBe(false)
    })

    it('should throw when starting while already recording', async () => {
      const recorder = createAudioRecorder()
      await recorder.start()
      await expect(recorder.start()).rejects.toThrow('Already recording')
    })

    it('should throw when stopping without recording', async () => {
      const recorder = createAudioRecorder()
      await expect(recorder.stop()).rejects.toThrow('Not recording')
    })
  })

  describe('getUserMedia', () => {
    it('should request microphone with correct audio constraints', async () => {
      const recorder = createAudioRecorder()
      await recorder.start()

      expect(navigator.mediaDevices.getUserMedia).toHaveBeenCalledWith({
        audio: {
          sampleRate: 16000,
          channelCount: 1,
          echoCancellation: true,
          noiseSuppression: true,
        },
      })
    })
  })

  describe('MediaRecorder usage', () => {
    it('should start MediaRecorder with 100ms timeslice', async () => {
      const recorder = createAudioRecorder()
      await recorder.start()
      expect(mockRecorderInstance.start).toHaveBeenCalledWith(100)
    })

    it('should call MediaRecorder.stop() when stop() is called', async () => {
      const recorder = createAudioRecorder()
      await recorder.start()
      await recorder.stop()
      expect(mockRecorderInstance.stop).toHaveBeenCalled()
    })

    it('should stop all media stream tracks on stop()', async () => {
      const mockStream = createMockMediaStream()
      vi.mocked(navigator.mediaDevices.getUserMedia).mockResolvedValue(mockStream)

      const recorder = createAudioRecorder()
      await recorder.start()
      await recorder.stop()

      const tracks = mockStream.getTracks()
      for (const track of tracks) {
        expect(track.stop).toHaveBeenCalled()
      }
    })
  })

  describe('start() returns ReadableStream', () => {
    it('should return a ReadableStream from start()', async () => {
      const recorder = createAudioRecorder()
      const stream = await recorder.start()
      expect(stream).toBeInstanceOf(ReadableStream)
    })
  })

  describe('stop() returns combined ArrayBuffer', () => {
    it('should return an ArrayBuffer from stop()', async () => {
      const recorder = createAudioRecorder()

      // Use a mock that does NOT auto-fire stop so we can inject data first
      mockRecorderInstance.stop.mockImplementation(() => {
        // fire stop asynchronously so the onstop handler is set
        mockRecorderInstance._fireStop()
      })

      await recorder.start()

      // Simulate data chunks arriving
      await mockRecorderInstance._fireDataAvailable(new Uint8Array([1, 2, 3]).buffer)
      await mockRecorderInstance._fireDataAvailable(new Uint8Array([4, 5]).buffer)

      const result = await recorder.stop()
      expect(result).toBeInstanceOf(ArrayBuffer)
      expect(new Uint8Array(result)).toEqual(new Uint8Array([1, 2, 3, 4, 5]))
    })

    it('should return empty ArrayBuffer when no data was recorded', async () => {
      const recorder = createAudioRecorder()
      await recorder.start()
      const result = await recorder.stop()
      expect(result).toBeInstanceOf(ArrayBuffer)
      expect(result.byteLength).toBe(0)
    })
  })
})
