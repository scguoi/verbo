import AVFoundation
import CoreAudio

// MARK: - AudioRecorder

/// Records via `AVAudioRecorder` to a temp WAV file AND simultaneously
/// tails the growing file to yield 16 kHz Int16 mono PCM chunks in
/// real-time. This gives iFlytek partial results while the user is still
/// speaking, without depending on AVAudioEngine (which is unreliable
/// with AirPods on macOS).
actor AudioRecorder {

    // MARK: - Constants

    /// 40 ms at 16 kHz 16-bit mono = 16000 × 0.04 × 2 = 1280 bytes.
    static let chunkSize = 1280

    /// WAV header size for our specific format (Linear PCM). Standard
    /// RIFF header = 44 bytes for single-format uncompressed PCM.
    private static let wavHeaderSize: UInt64 = 44

    static let levelCount = 20

    // MARK: - Private Properties

    private var recorder: AVAudioRecorder?
    private var streamContinuation: AsyncStream<Data>.Continuation?
    private var levelPollTask: Task<Void, Never>?
    private var streamingTask: Task<Void, Never>?
    private(set) var isRecording = false
    private var peakDB: Float = -45

    private let recordingURL: URL = {
        FileManager.default.temporaryDirectory.appendingPathComponent("verbo-recording.wav")
    }()

    // MARK: - Public Properties

    private(set) var audioLevels: [Float] = Array(repeating: 0, count: AudioRecorder.levelCount)

    // MARK: - Start

    /// Begin recording. Returns a stream that yields 40 ms 16 kHz Int16
    /// mono PCM chunks IN REAL-TIME while the user is still speaking.
    /// The stream finishes when `stop()` is called and any remaining
    /// bytes have been flushed.
    func start() -> AsyncStream<Data> {
        let t0 = DispatchTime.now().uptimeNanoseconds
        DebugLog.write("[audio] start() enter")

        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        DebugLog.write("[audio] mic TCC=\(Self.authName(authStatus))")
        Self.logDefaultInputDevice()
        Self.overrideDefaultInputIfVirtual()

        audioLevels = Array(repeating: 0, count: Self.levelCount)
        peakDB = -45

        let stream = AsyncStream<Data> { continuation in
            self.streamContinuation = continuation
        }

        try? FileManager.default.removeItem(at: recordingURL)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        do {
            let newRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            newRecorder.isMeteringEnabled = true
            guard newRecorder.prepareToRecord() else {
                DebugLog.write("[audio] prepareToRecord() returned false")
                streamContinuation?.finish()
                streamContinuation = nil
                return stream
            }
            guard newRecorder.record() else {
                DebugLog.write("[audio] record() returned false")
                streamContinuation?.finish()
                streamContinuation = nil
                return stream
            }
            recorder = newRecorder
            isRecording = true
            startLevelPolling()
            startStreamingFromFile()
            DebugLog.write("[audio] recording started t+\(Self.ms(t0))ms")
        } catch {
            DebugLog.write("[audio] AVAudioRecorder init failed: \(error.localizedDescription)")
            streamContinuation?.finish()
            streamContinuation = nil
        }

        return stream
    }

    // MARK: - Stop

    func stop() -> Data {
        guard recorder != nil else {
            DebugLog.write("[audio] stop() — no active recorder, noop")
            streamContinuation?.finish()
            streamContinuation = nil
            return Data()
        }

        let t0 = DispatchTime.now().uptimeNanoseconds
        recorder?.stop()
        recorder = nil
        isRecording = false
        levelPollTask?.cancel()
        levelPollTask = nil

        // The streaming task detects isRecording == false, flushes
        // remaining bytes, and finishes the stream. We don't finish
        // it here to avoid a race.
        DebugLog.write("[audio] stop() t+\(Self.ms(t0))ms — waiting for streaming task to flush")

        return Data()
    }

    // MARK: - Real-time file tailing

    /// Periodically reads new bytes from the growing WAV file, converts
    /// Float32 → Int16, and yields 1280-byte chunks on the stream. This
    /// runs concurrently with AVAudioRecorder writing to the same file.
    private func startStreamingFromFile() {
        streamingTask?.cancel()
        streamingTask = Task { [weak self] in
            guard let self else { return }

            // Give the recorder a moment to write the WAV header.
            try? await Task.sleep(for: .milliseconds(100))

            let url = self.recordingURL
            guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
                DebugLog.write("[audio] streaming: cannot open file for reading")
                await self.finishStream()
                return
            }
            defer { try? fileHandle.close() }

            // Skip the 44-byte WAV header.
            try? fileHandle.seek(toOffset: Self.wavHeaderSize)
            var readOffset = Self.wavHeaderSize
            var int16Buffer = Data()
            var totalYielded = 0

            while true {
                let stillRecording = await self.isRecording

                // Read whatever new bytes the recorder has written.
                try? fileHandle.seek(toOffset: readOffset)
                let newData = fileHandle.readDataToEndOfFile()

                if newData.count >= 4 {
                    // Convert Float32 → Int16 and accumulate.
                    let int16Chunk = Self.float32ToInt16(newData)
                    int16Buffer.append(int16Chunk)
                    readOffset += UInt64(newData.count)

                    // Yield complete 1280-byte chunks.
                    while int16Buffer.count >= Self.chunkSize {
                        let chunk = int16Buffer.prefix(Self.chunkSize)
                        await self.yieldChunk(Data(chunk))
                        totalYielded += 1
                        int16Buffer = int16Buffer.dropFirst(Self.chunkSize)
                    }
                }

                if !stillRecording {
                    // Recorder stopped. Do one final read to catch any
                    // bytes written between our last poll and stop().
                    try? fileHandle.seek(toOffset: readOffset)
                    let finalData = fileHandle.readDataToEndOfFile()
                    if finalData.count >= 4 {
                        int16Buffer.append(Self.float32ToInt16(finalData))
                        while int16Buffer.count >= Self.chunkSize {
                            let chunk = int16Buffer.prefix(Self.chunkSize)
                            await self.yieldChunk(Data(chunk))
                            totalYielded += 1
                            int16Buffer = int16Buffer.dropFirst(Self.chunkSize)
                        }
                    }
                    break
                }

                try? await Task.sleep(for: .milliseconds(80))
            }

            DebugLog.write("[audio] streaming done: yielded=\(totalYielded) chunks")
            await self.finishStream()

            // Clean up the temp file.
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func yieldChunk(_ data: Data) {
        streamContinuation?.yield(data)
    }

    private func finishStream() {
        streamContinuation?.finish()
        streamContinuation = nil
    }

    /// Convert a block of little-endian Float32 samples to Int16.
    private static func float32ToInt16(_ data: Data) -> Data {
        let floatCount = data.count / 4
        guard floatCount > 0 else { return Data() }
        return data.withUnsafeBytes { raw in
            let floats = raw.bindMemory(to: Float.self)
            var int16s = [Int16](repeating: 0, count: floatCount)
            for i in 0..<floatCount {
                let clamped = max(-1.0, min(1.0, floats[i]))
                int16s[i] = Int16(clamped * 32767.0)
            }
            return int16s.withUnsafeBufferPointer { Data(buffer: $0) }
        }
    }

    // MARK: - Level polling

    private func startLevelPolling() {
        levelPollTask?.cancel()
        levelPollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollOneLevel()
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func pollOneLevel() {
        guard let rec = recorder, rec.isRecording else { return }
        rec.updateMeters()
        let powerDB = rec.averagePower(forChannel: 0)

        if powerDB > peakDB { peakDB = powerDB }

        let floor: Float = -45
        let range = max(peakDB - floor, 10)
        let level: Float
        if powerDB < floor {
            level = 0
        } else {
            level = min(1, max(0, (powerDB - floor) / range))
        }

        var next = audioLevels
        next.removeFirst()
        next.append(level)
        audioLevels = next
    }

    // MARK: - Diagnostics

    private static func ms(_ startNs: UInt64) -> Int {
        Int((DispatchTime.now().uptimeNanoseconds &- startNs) / 1_000_000)
    }

    private static func authName(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted:    return "restricted"
        case .denied:        return "denied"
        case .authorized:    return "authorized"
        @unknown default:    return "unknown"
        }
    }

    private static func logDefaultInputDevice() {
        guard let deviceID = defaultInputDeviceID() else {
            DebugLog.write("[audio] defaultInputDevice query failed")
            return
        }
        let name = deviceName(id: deviceID) ?? "?"

        var streamsAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var streamsSize: UInt32 = 0
        _ = AudioObjectGetPropertyDataSize(deviceID, &streamsAddr, 0, nil, &streamsSize)
        let streamCount = Int(streamsSize) / MemoryLayout<AudioStreamID>.size

        DebugLog.write("[audio] defaultInput name=\(name) inputStreams=\(streamCount)")
    }

    // MARK: - Virtual input device override

    private static let virtualDeviceNameFragments = [
        "iflyrec", "blackhole", "soundflower", "loopback",
        "vb-audio", "vb audio", "ishowu", "virtual",
        "screen capture", "aggregate",
    ]

    private static func overrideDefaultInputIfVirtual() {
        guard let currentID = defaultInputDeviceID() else { return }
        let currentName = deviceName(id: currentID) ?? ""
        guard isVirtualDevice(id: currentID, name: currentName) else { return }

        DebugLog.write("[audio] default input '\(currentName)' looks virtual — picking real mic")
        guard let replacementID = pickBestRealInputDevice(excluding: currentID) else {
            DebugLog.write("[audio] no real mic candidate; staying with '\(currentName)'")
            return
        }
        let replacementName = deviceName(id: replacementID) ?? "?"

        var idValue = replacementID
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addr, 0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &idValue
        )
        if status == noErr {
            DebugLog.write("[audio] system default input → '\(replacementName)'")
        } else {
            DebugLog.write("[audio] failed to set default input status=\(status)")
        }
    }

    private static func defaultInputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addr, 0, nil, &size, &deviceID
        )
        return status == noErr ? deviceID : nil
    }

    private static func pickBestRealInputDevice(excluding excluded: AudioDeviceID) -> AudioDeviceID? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &addr, 0, nil, &size
        ) == noErr else { return nil }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addr, 0, nil, &size, &ids
        ) == noErr else { return nil }

        var best: (AudioDeviceID, Int)?
        for id in ids where id != excluded {
            guard hasInputStreams(id: id) else { continue }
            let name = deviceName(id: id) ?? ""
            let score = scoreDevice(id: id, name: name)
            if score < 0 { continue }
            if best == nil || score > best!.1 {
                best = (id, score)
            }
        }
        return best?.0
    }

    private static func scoreDevice(id: AudioDeviceID, name: String) -> Int {
        if isVirtualDevice(id: id, name: name) { return -1 }
        let transport = deviceTransportType(id: id)
        switch transport {
        case kAudioDeviceTransportTypeBuiltIn:    return 100
        case kAudioDeviceTransportTypeUSB:        return 80
        case kAudioDeviceTransportTypeBluetooth,
             kAudioDeviceTransportTypeBluetoothLE: return 70
        case kAudioDeviceTransportTypeThunderbolt: return 60
        case kAudioDeviceTransportTypeDisplayPort: return 50
        case kAudioDeviceTransportTypeAirPlay:    return 40
        default:                                  return 30
        }
    }

    private static func isVirtualDevice(id: AudioDeviceID, name: String) -> Bool {
        let lower = name.lowercased()
        for fragment in virtualDeviceNameFragments where lower.contains(fragment) {
            return true
        }
        let transport = deviceTransportType(id: id)
        return transport == kAudioDeviceTransportTypeVirtual
            || transport == kAudioDeviceTransportTypeAggregate
    }

    private static func deviceTransportType(id: AudioDeviceID) -> UInt32 {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &transport)
        return status == noErr ? transport : 0
    }

    private static func hasInputStreams(id: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size)
        return status == noErr && size > 0
    }

    private static func deviceName(id: AudioDeviceID) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<CFString?>.size)
        var cfString: CFString?
        let status = withUnsafeMutablePointer(to: &cfString) { ptr in
            AudioObjectGetPropertyData(id, &addr, 0, nil, &size, ptr)
        }
        guard status == noErr, let cf = cfString else { return nil }
        return cf as String
    }
}

extension AudioRecorder: AudioRecording {}
