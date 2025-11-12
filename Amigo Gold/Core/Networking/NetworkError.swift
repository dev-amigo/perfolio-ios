import Foundation

enum NetworkError: Error {
    case invalidURL
    case decodingFailed
    case server(code: Int, description: String?)
    case transport(Error)
    case missingData

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid request URL."
        case .decodingFailed:
            return "Unable to decode server response."
        case let .server(code, description):
            return "Server error (\(code)) \(description ?? "")"
        case let .transport(error):
            return error.localizedDescription
        case .missingData:
            return "No data returned from server."
        }
    }
}
