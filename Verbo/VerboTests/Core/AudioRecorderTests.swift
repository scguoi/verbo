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

    @Test("Chunk size is 1280 bytes (40ms at 16 kHz Int16 mono)")
    func chunkSizeIs1280Bytes() {
        #expect(AudioRecorder.chunkSize == 1280)
    }

    @Test("Level window size is 20")
    func levelWindowSizeIs20() {
        #expect(AudioRecorder.levelCount == 20)
    }
}
