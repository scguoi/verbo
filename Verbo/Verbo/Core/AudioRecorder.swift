import AVFoundation
import CoreAudio

// MARK: - AudioRecorder

/// Records a single session via `AVAudioRecorder` to a temp WAV file, then
/// (on stop) reads the file, converts Float32 → Int16, and yields the PCM
/// chunks on the AsyncStream returned by `start()`.
///
/// Why AVAudioRecorder instead of AVAudioEngine:
/// - OpenSuperWhisper, Vocorize, AudioWhisper — three production macOS
///   dictation apps — all use this path. It handles AirPods HFP/A2DP
///   negotiation, microphone volume, and format conversion internally.
/// - `AVAudioEngine` on macOS is a minefield for recording: mainMixer
///   doesn't auto-convert formats, inputNode needs a render target to
///   pump, `inputFormat(forBus:)` is stale until HAL settles, Bluetooth
///   devices don't unbind cleanly, etc. FluidVoice — the one dictation app
///   using it — has 2800 lines of workarounds in its ASRService alone.
actor AudioRecorder {

    // MARK: - Constants

    /// 40 ms at 16 kHz 16-bit mono = 16000 × 0.04 × 2 = 1280 bytes.
    /// Matches iFlytek Spark IAT's expected frame cadence.
    static let chunkSize = 1280

    static let levelCount = 20

    // MARK: - Private Properties

    private var recorder: AVAudioRecorder?
    private var streamContinuation: AsyncStream<Data>.Continuation?
    private var levelPollTask: Task<Void, Never>?
    private(set) var isRecording = false

    /// Tracks the loudest sample seen in this recording session so the
    /// visualization range auto-calibrates to any mic gain / distance.
    private var peakDB: Float = -45

    private let recordingURL: URL = {
        FileManager.default.temporaryDirectory.appendingPathComponent("verbo-recording.wav")
    }()

    // MARK: - Public Properties

    /// Sliding window of audio amplitude samples, updated every ~100 ms
    /// while recording. Consumed by the floating pill's visualizer.
    private(set) var audioLevels: [Float] = Array(repeating: 0, count: AudioRecorder.levelCount)

    // MARK: - Start

    /// Begin a new recording session. Returns a stream that yields 40 ms
    /// 16 kHz Int16 mono PCM chunks on stop — the stream does NOT yield
    /// during recording (the file accumulates locally instead). On stop
    /// the entire recording is read back from disk, converted, and
    /// yielded rapidly, then the stream finishes.
    func start() -> AsyncStream<Data> {
        let t0 = DispatchTime.now().uptimeNanoseconds
        DebugLog.write("[audio] start() enter")

        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        DebugLog.write("[audio] mic TCC=\(Self.authName(authStatus))")
        Self.logDefaultInputDevice()

        // If the system default input is a virtual / loopback capture
        // driver, override it to a real mic BEFORE starting the recorder.
        // AVAudioRecorder always records from the current system default,
        // so this is the only hook we have to avoid iFlyrec et al.
        Self.overrideDefaultInputIfVirtual()

        audioLevels = Array(repeating: 0, count: Self.levelCount)
        peakDB = -45

        let stream = AsyncStream<Data> { continuation in
            self.streamContinuation = continuation
        }

        // Wipe any leftover file from a previous session so stop() never
        // reads stale audio on a failed start.
        try? FileManager.default.removeItem(at: recordingURL)

        // Vocorize's proven settings: 16 kHz mono Float32 little-endian.
        // AVAudioRecorder handles resampling + downmixing from whatever
        // format the hardware actually delivers (including AirPods' 24 kHz
        // HFP or 48 kHz A2DP), so we don't have to.
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
            DebugLog.write("[audio] recording started t+\(Self.ms(t0))ms → \(recordingURL.lastPathComponent)")
        } catch {
            DebugLog.write("[audio] AVAudioRecorder init failed: \(error.localizedDescription)")
            streamContinuation?.finish()
            streamContinuation = nil
        }

        return stream
    }

    // MARK: - Stop

    /// Stop the recording, read the WAV file, convert Float32 → Int16,
    /// yield all chunks on the stream, then finish it. Returns any
    /// sub-chunk remainder (never used by our caller but preserved for
    /// AudioRecording protocol compatibility).
    func stop() -> Data {
        guard let rec = recorder else {
            DebugLog.write("[audio] stop() — no active recorder, noop")
            streamContinuation?.finish()
            streamContinuation = nil
            return Data()
        }

        let t0 = DispatchTime.now().uptimeNanoseconds
        rec.stop()
        recorder = nil
        isRecording = false
        levelPollTask?.cancel()
        levelPollTask = nil

        let pcm = Self.readWavAsInt16Mono16k(url: recordingURL)
        DebugLog.write("[audio] stop() wav bytes=\(pcm.count) (\(pcm.count / Self.chunkSize) chunks)")

        var yielded = 0
        var offset = 0
        while offset + Self.chunkSize <= pcm.count {
            let chunk = pcm.subdata(in: offset..<(offset + Self.chunkSize))
            streamContinuation?.yield(chunk)
            yielded += 1
            offset += Self.chunkSize
        }

        streamContinuation?.finish()
        streamContinuation = nil

        DebugLog.write("[audio] stop() yielded=\(yielded) chunks t+\(Self.ms(t0))ms")

        // Clean up the temp file — we've already streamed its contents.
        try? FileManager.default.removeItem(at: recordingURL)

        return Data()
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

        // Track the loudest sample in this session so the range auto-
        // calibrates. Fixed floor at -45 dBFS — from real recordings
        // this sits right between "pause between words" (-44 to -52 dB)
        // and "quiet consonant" (-35 to -40 dB), giving clean zero
        // during gaps. The range = [floor, peak] expands automatically
        // as the user speaks louder.
        if powerDB > peakDB { peakDB = powerDB }

        let floor: Float = -45
        let range = max(peakDB - floor, 10)  // at least 10 dB range
        let level: Float
        if powerDB < floor {
            level = 0
        } else {
            level = min(1, max(0, (powerDB - floor) / range))
        }

        // Sliding window: each bar is one historical sample.
        var next = audioLevels
        next.removeFirst()
        next.append(level)
        audioLevels = next
    }

    // MARK: - WAV reading (Float32 → Int16)

    /// Read the recorded WAV as 16 kHz mono Int16 little-endian PCM.
    /// Uses AVAudioFile instead of hand-parsing WAV headers because
    /// AVAudioFile correctly handles all RIFF chunk layouts.
    private static func readWavAsInt16Mono16k(url: URL) -> Data {
        guard FileManager.default.fileExists(atPath: url.path) else {
            DebugLog.write("[audio] WAV missing at \(url.path)")
            return Data()
        }
        do {
            let file = try AVAudioFile(forReading: url)
            let frameCount = AVAudioFrameCount(file.length)
            guard frameCount > 0 else {
                DebugLog.write("[audio] WAV has zero frames")
                return Data()
            }
            // AVAudioFile's processingFormat is always Float32 deinterleaved.
            let format = file.processingFormat
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                DebugLog.write("[audio] AVAudioPCMBuffer alloc failed")
                return Data()
            }
            try file.read(into: buffer)
            guard let channelData = buffer.floatChannelData else {
                DebugLog.write("[audio] WAV has no float channel data")
                return Data()
            }

            let count = Int(buffer.frameLength)
            let channel0 = channelData[0]

            // Convert Float32 [-1, 1] → Int16 [-32768, 32767].
            var int16 = [Int16](repeating: 0, count: count)
            for i in 0..<count {
                let f = channel0[i]
                let clamped = max(-1.0, min(1.0, f))
                int16[i] = Int16(clamped * 32767.0)
            }
            return int16.withUnsafeBufferPointer { Data(buffer: $0) }
        } catch {
            DebugLog.write("[audio] WAV read error: \(error.localizedDescription)")
            return Data()
        }
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

    /// Blocklist of device-name substrings that identify virtual /
    /// loopback audio capture drivers. These expose themselves as input
    /// devices but record system output, not a real mic.
    private static let virtualDeviceNameFragments = [
        "iflyrec", "blackhole", "soundflower", "loopback",
        "vb-audio", "vb audio", "ishowu", "virtual",
        "screen capture", "aggregate",
    ]

    /// If the system default input device is a virtual/loopback driver,
    /// pick the best real mic on the system and set it as the system
    /// default via CoreAudio HAL. This does change the user's system
    /// setting, but only when the current default is clearly wrong for
    /// dictation (same approach OpenSuperWhisper and Vocorize take).
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
            DebugLog.write("[audio] candidate '\(name)' id=\(id) score=\(score)")
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
