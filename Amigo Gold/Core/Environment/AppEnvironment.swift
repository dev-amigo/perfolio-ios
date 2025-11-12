import Foundation

enum AppEnvironment: String {
    case development
    case production

    static func resolve(from bundle: Bundle = .main) -> AppEnvironment {
        let rawValue = bundle.object(forInfoDictionaryKey: "AGEnvironmentName") as? String
        return AppEnvironment(rawValue: rawValue ?? "") ?? .development
    }

    var displayName: String {
        rawValue.capitalized
    }
}
