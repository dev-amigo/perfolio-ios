import Foundation

enum AppLogger {
    static func log(_ message: String, category: String = "general") {
        #if DEBUG
        print("[AmigoGold][\(category)] \(message)")
        #endif
    }
}
