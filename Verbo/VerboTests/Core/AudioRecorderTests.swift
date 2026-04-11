import Testing
import AVFoundation
@testable import Verbo

// MARK: - AudioRecorder Tests

@Suite("AudioRecorder")
struct AudioRecorderTests {

    @Test("AudioRecorder starts in idle state")
    func audioRecorderStartsInIdleState() async {
        let recorder = AudioRecorder()
        let isRecording = await recorder.isRecording
        #expect(isRecording == false)
    }

    @Test("Target PCM format is 16kHz mono")
    func targetFormatIs16KHzMono() {
        let format = AudioRecorder.targetFormat
        #expect(format.sampleRate == 16000)
        #expect(format.channelCount == 1)
    }

    @Test("Chunk size is 1280 bytes")
    func chunkSizeIs1280Bytes() {
        #expect(AudioRecorder.chunkSize == 1280)
    }
}
