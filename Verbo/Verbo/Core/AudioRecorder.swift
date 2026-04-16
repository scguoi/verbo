import AVFoundation
import CoreAudio

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

    /// Recreated on every `start()` call (and on configuration-change reconfigure).
    /// Reusing a single AVAudioEngine across multiple start/stop cycles has
    /// proven fragile: in rapid start→stop→start sequences (user double-taps
    /// the hotkey), `installTap` would throw `nullptr == Tap()` and SIGABRT
    /// the app (Swift cannot catch ObjC exceptions). Starting fresh on each
    /// recording trades ~100 ms of CoreAudio warmup for reliability.
    private var engine = AVAudioEngine()
    private(set) var isRecording = false
    private var audioBuffer = Data()
    private var streamContinuation: AsyncStream<Data>.Continuation?
    /// Captured by the tap closure so it can lazily build (and rebuild on
    /// format changes) an AVAudioConverter to the target 16 kHz Int16 mono.
    private var converterBox = ConverterBox()
    /// Counters surfaced on stop() so we can see whether audio is flowing.
    private var tapCallbackCount = 0
    private var chunksYielded = 0
    /// Notification token for `.AVAudioEngineConfigurationChange`. AirPods
    /// switching from A2DP to HFP fires this notification mid-session; we
    /// must reconfigure the tap and restart the engine to recover.
    nonisolated(unsafe) private var configChangeObserver: NSObjectProtocol?

    // MARK: - Public Properties

    static let levelCount = 20
    var audioLevels: [Float] = Array(repeating: 0, count: AudioRecorder.levelCount)

    // MARK: - Init / Deinit

    init() {
        // Subscribe to the AVAudioEngineConfigurationChange notification.
        // It fires when CoreAudio renegotiates with the underlying device,
        // most importantly when AirPods switches its Bluetooth profile from
        // A2DP (output-only, 48 kHz fake input) to HFP (24 kHz real mic) in
        // response to engine.start(). When that happens the engine is auto-
        // stopped by AVFoundation; if we don't reinstall the tap and restart
        // we get zero buffers forever.
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { await self?.handleConfigurationChange() }
        }
    }

    deinit {
        if let obs = configChangeObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Start Recording

    /// Installs a tap on the input node, converts audio to 16 kHz mono Int16,
    /// and yields chunks via an AsyncStream when enough bytes accumulate.
    func start() -> AsyncStream<Data> {
        let t0 = DispatchTime.now().uptimeNanoseconds
        DebugLog.write("[audio] start() enter")

        // Diagnostics: mic auth + default input device.
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        DebugLog.write("[audio] mic TCC=\(Self.authName(authStatus))")
        Self.logDefaultInputDevice()

        // AirPods warmup: if the input node currently reports a suspicious
        // sample rate (AirPods in A2DP mode exposes a 48 kHz fake-input
        // shim, but the real HFP mic uses 24 kHz or 16 kHz), run a short
        // AVAudioRecorder preroll to force CoreAudio to negotiate the SCO
        // link. This gives us a stable 24 kHz HFP stream by the time our
        // AVAudioEngine starts, avoiding the mid-session
        // AVAudioEngineConfigurationChange that produces corrupted audio.
        let probeEngine = AVAudioEngine()
        let probeFormat = probeEngine.inputNode.outputFormat(forBus: 0)
        if probeFormat.sampleRate >= 44100, probeFormat.channelCount == 1 {
            DebugLog.write("[audio] suspected A2DP fake-input (sr=\(probeFormat.sampleRate)) — running warmup")
            Self.warmupMicViaRecorder()
        }

        // Reset per-cycle state.
        audioBuffer = Data()
        tapCallbackCount = 0
        chunksYielded = 0
        converterBox = ConverterBox()

        // Build a stream and stash its continuation. Subsequent reconfigures
        // (config-change notifications) reuse this same continuation so the
        // upstream consumer doesn't see a gap.
        let stream = AsyncStream<Data> { continuation in
            self.streamContinuation = continuation
        }

        // Build the engine and start it. configureAndStart is also used by
        // the configuration-change recovery path.
        do {
            try configureAndStart(t0: t0)
            isRecording = true
        } catch {
            DebugLog.write("[audio] engine.start() THREW \(error.localizedDescription)")
            streamContinuation?.finish()
            streamContinuation = nil
        }

        return stream
    }

    /// Build a fresh AVAudioEngine, attach an AVAudioSinkNode to the input
    /// node, and start the engine. Used by `start()` and by
    /// `handleConfigurationChange()`. Throws if `engine.start()` fails.
    ///
    /// Why AVAudioSinkNode and not installTap+mainMixerNode: on macOS, the
    /// mainMixerNode pump approach works for built-in mics but silently
    /// drops buffers for AirPods, because `AVAudioMixerNode` on macOS
    /// doesn't auto-convert input formats the way iOS does — feeding it a
    /// 24 kHz mono HFP stream while the output is 44.1 kHz stereo causes
    /// the mixer to discard everything. AVAudioSinkNode is Apple's
    /// purpose-built "input-only capture" node (macOS 10.15+) with no
    /// mixer constraints, and reliably pulls audio through the graph.
    private func configureAndStart(t0: UInt64) throws {
        // Tear down whatever the previous engine had — the safest way to
        // make sure the input node has no residual tap and no orphaned
        // connections is to release the engine entirely.
        if engine.isRunning { engine.stop() }
        engine = AVAudioEngine()

        // If the system default input device looks like a virtual / loopback
        // capture driver (iFlyrec, BlackHole, Soundflower, etc.), it's not a
        // real microphone — it captures system output and delivers silence
        // or wrong data to us. Pick a real physical mic instead and force
        // the engine to use it.
        Self.overrideInputDeviceIfVirtual(engine: engine)

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        DebugLog.write("[audio] inputFormat sr=\(inputFormat.sampleRate) ch=\(inputFormat.channelCount) t+\(Self.ms(t0))ms")
        lastConfiguredSampleRate = inputFormat.sampleRate
        lastConfiguredChannels = inputFormat.channelCount

        let targetFormat = Self.targetFormat
        let box = converterBox

        // Sink node receives raw AudioBufferList from the render thread.
        // We wrap the incoming interleaved data into a fresh
        // AVAudioPCMBuffer so ConverterBox can run the same conversion
        // path used for the installTap-based code.
        let sinkNode = AVAudioSinkNode { [weak self, targetFormat] _, frameCount, audioBufferList in
            guard let self else { return noErr }
            guard frameCount > 0 else { return noErr }

            // Build an AVAudioPCMBuffer that wraps the incoming buffer list.
            // The buffer's format is the input node's format, so use the
            // cached reference from the closure.
            guard let pcmBuffer = AVAudioPCMBuffer(
                pcmFormat: inputFormat,
                bufferListNoCopy: audioBufferList
            ) else {
                return noErr
            }
            pcmBuffer.frameLength = AVAudioFrameCount(frameCount)

            Task { await self.incrementTapCount() }

            guard let data = ConverterBox.convert(
                buffer: pcmBuffer,
                targetFormat: targetFormat,
                box: box
            ) else { return noErr }

            Task { [data] in
                await self.pushAudio(data)
            }
            return noErr
        }

        engine.attach(sinkNode)
        engine.connect(inputNode, to: sinkNode, format: inputFormat)
        engine.prepare()

        DebugLog.write("[audio] engine.start() begin t+\(Self.ms(t0))ms")
        try engine.start()
        DebugLog.write("[audio] engine.start() done  t+\(Self.ms(t0))ms running=\(engine.isRunning)")
    }

    /// Tracks the input node format last seen inside `configureAndStart`.
    /// Used to debounce spurious AVAudioEngineConfigurationChange
    /// notifications: our own `engine.attach`/`connect` calls inside start
    /// can trigger the notification on the freshly-built engine, and
    /// blindly reconfiguring in response causes a restart loop that
    /// destabilizes CoreAudio (engine.start() has been observed to hang
    /// for 4+ seconds in this state).
    private var lastConfiguredSampleRate: Double = 0
    private var lastConfiguredChannels: AVAudioChannelCount = 0

    /// Called when AVAudioEngineConfigurationChange fires. AVFoundation has
    /// already stopped the engine when this fires — we MUST restart it or
    /// audio stops flowing (tap block never fires again). Two paths:
    /// 1. Format unchanged → just restart the existing engine (cheap).
    /// 2. Format changed → recreate the engine, reattach sink, restart.
    ///
    /// The upstream stream continuation stays alive across both so the
    /// consumer doesn't see a gap.
    private func handleConfigurationChange() {
        guard isRecording else { return }

        let currentFormat = engine.inputNode.outputFormat(forBus: 0)
        let formatUnchanged = currentFormat.sampleRate == lastConfiguredSampleRate
            && currentFormat.channelCount == lastConfiguredChannels

        if formatUnchanged {
            // Same format, just restart the current engine. Skipping the
            // restart here was the cause of recordings silently getting
            // zero tap callbacks: AVFoundation stops the engine on this
            // notification regardless of whether the format actually
            // changed, and leaving it stopped means no audio.
            if engine.isRunning {
                DebugLog.write("[audio] configChange — format unchanged, engine still running, skipping")
                return
            }
            DebugLog.write("[audio] configChange — format unchanged, restarting engine in-place")
            do {
                try engine.start()
            } catch {
                DebugLog.write("[audio] restart failed: \(error.localizedDescription) — falling back to full reconfigure")
                fullReconfigure()
            }
            return
        }

        DebugLog.write("[audio] AVAudioEngineConfigurationChange — format changed (\(lastConfiguredSampleRate)→\(currentFormat.sampleRate)), reconfiguring")
        fullReconfigure()
    }

    private func fullReconfigure() {
        let t0 = DispatchTime.now().uptimeNanoseconds
        converterBox = ConverterBox()
        do {
            try configureAndStart(t0: t0)
        } catch {
            DebugLog.write("[audio] reconfigure failed: \(error.localizedDescription)")
            isRecording = false
            streamContinuation?.finish()
            streamContinuation = nil
        }
    }

    // MARK: - Stop Recording

    /// Removes the tap, stops the engine, flushes any remaining buffered audio, and finishes the stream.
    func stop() -> Data {
        if engine.isRunning {
            engine.stop()
        }
        isRecording = false

        let remaining = audioBuffer
        audioBuffer = Data()
        streamContinuation?.finish()
        streamContinuation = nil

        DebugLog.write("[audio] stop() tapCallbacks=\(tapCallbackCount) chunksYielded=\(chunksYielded) bufferedBytesLeft=\(remaining.count)")

        return remaining
    }

    private func incrementTapCount() {
        tapCallbackCount += 1
    }

    // MARK: - Actor-isolated audio fan-in

    /// Audio thread → actor handoff. Only Sendable Data crosses the boundary.
    private func pushAudio(_ data: Data) {
        processAudioData(data)
        updateAudioLevels(from: data)
    }

    private func processAudioData(_ data: Data) {
        audioBuffer.append(data)
        while audioBuffer.count >= Self.chunkSize {
            let chunk = audioBuffer.prefix(Self.chunkSize)
            streamContinuation?.yield(Data(chunk))
            chunksYielded += 1
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

    // MARK: - Helpers

    private static func ms(_ startNs: UInt64) -> Int {
        Int((DispatchTime.now().uptimeNanoseconds &- startNs) / 1_000_000)
    }

    /// Blocklist of device-name substrings that identify virtual /
    /// loopback audio capture drivers. These expose themselves as input
    /// devices but record system output, not a real mic.
    private static let virtualDeviceNameFragments = [
        "iflyrec", "blackhole", "soundflower", "loopback",
        "vb-audio", "vb audio", "ishowu", "virtual",
        "screen capture", "aggregate",
    ]

    /// If the current default input device looks like a virtual/loopback
    /// capture driver, find the best real mic on the system and set it as
    /// the engine's input device via AUAudioUnit. Falls back silently if
    /// no alternative is available.
    private static func overrideInputDeviceIfVirtual(engine: AVAudioEngine) {
        guard let defaultID = defaultInputDeviceID() else { return }
        let defaultName = deviceName(id: defaultID) ?? ""
        let defaultIsVirtual = isVirtualDevice(id: defaultID, name: defaultName)

        if !defaultIsVirtual {
            return  // system default looks fine, let AVAudioEngine use it
        }

        DebugLog.write("[audio] default input '\(defaultName)' looks virtual — picking real mic")
        guard let replacementID = pickBestRealInputDevice(excluding: defaultID) else {
            DebugLog.write("[audio] no real mic candidate found; staying with '\(defaultName)'")
            return
        }
        let replacementName = deviceName(id: replacementID) ?? "?"
        DebugLog.write("[audio] overriding input device → '\(replacementName)' (id=\(replacementID))")

        guard let audioUnit = engine.inputNode.audioUnit else {
            DebugLog.write("[audio] inputNode.audioUnit is nil, cannot override device")
            return
        }
        var idValue = replacementID
        let err = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &idValue,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if err != noErr {
            DebugLog.write("[audio] AudioUnitSetProperty CurrentDevice failed status=\(err)")
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

    /// Enumerate all audio devices with at least one input stream, score
    /// them by "realness" (built-in > USB/Bluetooth > unknown > virtual),
    /// return the highest-scoring one excluding a given id.
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
            DebugLog.write("[audio] candidate name='\(name)' id=\(id) score=\(score)")
            if score < 0 { continue }
            if best == nil || score > best!.1 {
                best = (id, score)
            }
        }
        return best?.0
    }

    private static func scoreDevice(id: AudioDeviceID, name: String) -> Int {
        if isVirtualDevice(id: id, name: name) {
            return -1  // never pick this
        }
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
        getDeviceString(id: id, selector: kAudioObjectPropertyName)
    }

    /// Preroll an AVAudioRecorder for ~300 ms. AVAudioRecorder uses a
    /// different internal path than AVAudioEngine and reliably forces
    /// Bluetooth headsets into their mic-capable HFP profile. After the
    /// recorder stops, the device stays in HFP for several seconds —
    /// plenty of time for our AVAudioEngine to attach with a stable
    /// 24 kHz stream. The recording is discarded.
    private static func warmupMicViaRecorder() {
        let t0 = DispatchTime.now().uptimeNanoseconds
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("verbo-warmup.m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue,
        ]
        do {
            let rec = try AVAudioRecorder(url: tempURL, settings: settings)
            guard rec.prepareToRecord() else {
                DebugLog.write("[audio] warmup prepare FAILED")
                return
            }
            guard rec.record() else {
                DebugLog.write("[audio] warmup record FAILED")
                return
            }
            // Block the actor briefly. 300 ms is enough for AirPods SCO
            // negotiation on modern macOS; any longer would delay the
            // user-visible recording start.
            Thread.sleep(forTimeInterval: 0.30)
            rec.stop()
            try? FileManager.default.removeItem(at: tempURL)
            DebugLog.write("[audio] warmup done t+\(Self.ms(t0))ms")
        } catch {
            DebugLog.write("[audio] warmup failed: \(error.localizedDescription)")
        }
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

    /// Queries CoreAudio for the system's default input device and writes its
    /// ID / name / input-stream count to debug.log. Used to spot routing
    /// problems (virtual loopback device, AirPods in A2DP-only mode, etc.).
    private static func logDefaultInputDevice() {
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
        guard status == noErr else {
            DebugLog.write("[audio] defaultInputDevice query failed status=\(status)")
            return
        }

        let name = getDeviceString(id: deviceID, selector: kAudioObjectPropertyName) ?? "?"

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

    private static func getDeviceString(id: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector,
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

// MARK: - ConverterBox

/// Holds a cached AVAudioConverter for the tap block. Lives in the closure
/// captures (per recording cycle) so each start() — and each reconfigure — has
/// its own. The audio thread is single-threaded from our POV so no locking is
/// required. Marked @unchecked Sendable so it can be captured in the Sendable
/// tap closure.
final class ConverterBox: @unchecked Sendable {
    private var key: String = ""
    private var converter: AVAudioConverter?

    /// Convert an input buffer to the target format (16 kHz Int16 mono).
    /// Rebuilds the converter if the source format changes (AirPods HFP/A2DP
    /// renegotiation, manual device switch).
    static func convert(
        buffer: AVAudioPCMBuffer,
        targetFormat: AVAudioFormat,
        box: ConverterBox
    ) -> Data? {
        let sourceFormat = buffer.format
        guard sourceFormat.sampleRate > 0, buffer.frameLength > 0 else { return nil }

        let key = "\(sourceFormat.sampleRate)_\(sourceFormat.channelCount)_\(sourceFormat.commonFormat.rawValue)"
        if box.key != key {
            guard let c = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
                DebugLog.write("[audio] converter build FAILED sr=\(sourceFormat.sampleRate) ch=\(sourceFormat.channelCount)")
                return nil
            }
            box.converter = c
            box.key = key
            DebugLog.write("[audio] converter \(sourceFormat.sampleRate)Hz/\(sourceFormat.channelCount)ch → \(targetFormat.sampleRate)Hz")
        }
        guard let converter = box.converter else { return nil }

        let frameCapacity = AVAudioFrameCount(
            ceil(Double(buffer.frameLength) * targetFormat.sampleRate / sourceFormat.sampleRate)
        )
        guard frameCapacity > 0,
              let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity)
        else {
            return nil
        }

        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, error == nil else {
            DebugLog.write("[audio] convert error \(error?.localizedDescription ?? "?")")
            return nil
        }

        let byteCount = Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size
        guard byteCount > 0, let channelData = outputBuffer.int16ChannelData else { return nil }

        return Data(bytes: channelData[0], count: byteCount)
    }
}
