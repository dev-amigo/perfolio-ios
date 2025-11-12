import Foundation

struct APIEndpoint {
    enum Method: String {
        case get = "GET"
        case post = "POST"
    }

    let path: String
    let method: Method
    var queryItems: [URLQueryItem]

    init(path: String, method: Method = .get, queryItems: [URLQueryItem] = []) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
    }
}
