import os.log
import Foundation

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
