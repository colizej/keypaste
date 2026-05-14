import Foundation
import os

// Minimal logger. Writes structured events to os_log and to a rotating
// file in Application Support. Never logs key contents — only metadata.

enum Logger {
    private static let subsystem = "com.dramius.keypaste"
    private static let osLog = os.Logger(subsystem: subsystem, category: "app")

    static func info(_ message: String) {
        osLog.info("\(message, privacy: .public)")
    }

    static func warning(_ message: String) {
        osLog.warning("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        osLog.error("\(message, privacy: .public)")
    }

    static func debug(_ message: String) {
        osLog.debug("\(message, privacy: .public)")
    }
}
