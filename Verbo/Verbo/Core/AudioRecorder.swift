import AVFoundation

// MARK: - AudioRecorder

actor AudioRecorder {

    // MARK: - Constants

    static let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16000,
        channels: 1,
        interleaved: true
    )!

    /// 40ms at 16kHz 16-bit mono: 16000 samples/s * 0.04s * 2 bytes/sample = 1280 bytes
    static let chunkSize = 1280

    // MARK: - Private Properties

    private let engine = AVAudioEngine()
    private(set) var isRecording = false
    private var audioBuffer = Data()
    private var streamContinuation: AsyncStream<Data>.Continuation?

    // MARK: - Public Properties

    static let levelCount = 20
    var audioLevels: [Float] = Array(repeating: 0, count: AudioRecorder.levelCount)

    // MARK: - Start Recording

    /// Installs a tap on the input node, converts audio to 16kHz mono Int16,
    /// and yields chunks via an AsyncStream when enough bytes accumulate.
    func start() -> AsyncStream<Data> {
        let stream = AsyncStream<Data> { continuation in
            self.streamContinuation = continuation
        }

        let inputNode = engine.inputNode

        // Remove any existing tap to prevent crash on re-install
        inputNode.removeTap(onBus: 0)
        if engine.isRunning {
            engine.stop()
        }

        let inputFormat = inputNode.outputFormat(forBus: 0)

        let targetFormat = Self.targetFormat

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            return stream
        }

        let bufferSize = AVAudioFrameCount(inputFormat.sampleRate * 0.04)

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }

            let frameCapacity = AVAudioFrameCount(
                Double(buffer.frameLength) * targetFormat.sampleRate / inputFormat.sampleRate
            )
            guard frameCapacity > 0,
                  let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity)
            else {
                return
            }

            var error: NSError?
            let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            guard status != .error, error == nil else { return }

            let byteCount = Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size
            guard byteCount > 0,
                  let channelData = outputBuffer.int16ChannelData
            else {
                return
            }

            let data = Data(bytes: channelData[0], count: byteCount)

            Task {
                await self.processAudioData(data)
                await self.updateAudioLevels(from: data)
            }
        }

        do {
            try engine.start()
            isRecording = true
        } catch {
            streamContinuation?.finish()
        }

        return stream
    }

    // MARK: - Stop Recording

    /// Removes the tap, stops the engine, flushes any remaining buffered audio, and finishes the stream.
    func stop() -> Data {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false

        let remaining = audioBuffer
        audioBuffer = Data()
        streamContinuation?.finish()
        streamContinuation = nil

        return remaining
    }

    // MARK: - Private Helpers

    private func processAudioData(_ data: Data) {
        audioBuffer.append(data)
        while audioBuffer.count >= Self.chunkSize {
            let chunk = audioBuffer.prefix(Self.chunkSize)
            streamContinuation?.yield(Data(chunk))
            audioBuffer = audioBuffer.dropFirst(Self.chunkSize)
        }
    }

    private func updateAudioLevels(from data: Data) {
        let sampleCount = data.count / MemoryLayout<Int16>.size
        guard sampleCount > 0 else { return }

        let samples = data.withUnsafeBytes { buffer -> [Int16] in
            Array(buffer.bindMemory(to: Int16.self))
        }

        let segmentSize = max(1, sampleCount / Self.levelCount)
        var levels = [Float](repeating: 0, count: Self.levelCount)

        for i in 0..<Self.levelCount {
            let start = i * segmentSize
            let end = min(start + segmentSize, sampleCount)
            guard start < end else { continue }

            let segment = samples[start..<end]
            let avgAmplitude = segment.map { Float(Int32($0).magnitude) }.reduce(0, +) / Float(segment.count)
            levels[i] = avgAmplitude / Float(Int16.max)
        }

        audioLevels = levels
    }
}
