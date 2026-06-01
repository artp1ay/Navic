import Foundation
import OSLog

enum AppLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.freakware.navic"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let api = Logger(subsystem: subsystem, category: "navidrome.api")
    static let player = Logger(subsystem: subsystem, category: "player")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
