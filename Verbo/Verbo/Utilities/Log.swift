import os.log
import Foundation

/// Always-on timestamped debug log at `~/.verbo/debug.log`. Used for
/// cross-component latency tracing where os.log's out-of-process delivery
/// would obscure timing. Thread-safe via an internal serial queue.
enum DebugLog {
    private static let queue = DispatchQueue(label: "com.verbo.debug-log")
    nonisolated(unsafe) private static var cachedHandle: FileHandle?
    nonisolated(unsafe) private static var didSetup = false

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func write(_ message: String) {
        let stamp = formatter.string(from: Date())
        let line = "\(stamp) \(message)\n"
        queue.async {
            if !didSetup {
                let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".verbo")
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let path = dir.appendingPathComponent("debug.log")
                if !FileManager.default.fileExists(atPath: path.path) {
                    FileManager.default.createFile(atPath: path.path, contents: nil)
                }
                cachedHandle = try? FileHandle(forWritingTo: path)
                cachedHandle?.seekToEndOfFile()
                didSetup = true
            }
            if let data = line.data(using: .utf8) {
                cachedHandle?.write(data)
            }
        }
    }
}

enum Log {
    private static let subsystem = "com.verbo.app"

    static let stt = Logger(subsystem: subsystem, category: "STT")
    static let llm = Logger(subsystem: subsystem, category: "LLM")
    static let audio = Logger(subsystem: subsystem, category: "Audio")
    static let pipeline = Logger(subsystem: subsystem, category: "Pipeline")
    static let config = Logger(subsystem: subsystem, category: "Config")
    static let hotkey = Logger(subsystem: subsystem, category: "Hotkey")
    static let ui = Logger(subsystem: subsystem, category: "UI")

    /// Write to ~/.verbo/debug.log (Debug builds only)
    static func fileLog(_ message: String) {
        #if DEBUG
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".verbo")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("debug.log")
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
        if let data = line.data(using: .utf8) {
            if let fh = try? FileHandle(forWritingTo: path) {
                fh.seekToEndOfFile()
                fh.write(data)
                fh.closeFile()
            } else {
                try? data.write(to: path)
            }
        }
        #endif
    }
}
