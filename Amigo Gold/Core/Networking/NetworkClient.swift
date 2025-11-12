import Foundation

struct NetworkClient {
    private let session: URLSession
    private let configuration: EnvironmentConfiguration

    init(configuration: EnvironmentConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func send<T: Decodable>(_ endpoint: APIEndpoint, decode _: T.Type = T.self) async throws -> T {
        let request = try buildRequest(for: endpoint)
        do {
            let (data, response) = try await session.data(for: request)
            try validate(response: response)
            guard !data.isEmpty else { throw NetworkError.missingData }
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.transport(error)
        }
    }

    func send(_ endpoint: APIEndpoint) async throws {
        let request = try buildRequest(for: endpoint)
        do {
            let (_, response) = try await session.data(for: request)
            try validate(response: response)
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.transport(error)
        }
    }

    private func buildRequest(for endpoint: APIEndpoint) throws -> URLRequest {
        var components = URLComponents(url: configuration.apiBaseURL, resolvingAgainstBaseURL: false)
        components?.path = endpoint.path
        components?.queryItems = endpoint.queryItems.isEmpty ? nil : endpoint.queryItems
        guard let url = components?.url else { throw NetworkError.invalidURL }
        var request = URLRequest(url: url, timeoutInterval: AppConstants.defaultNetworkTimeout)
        request.httpMethod = endpoint.method.rawValue
        configuration.networkHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        return request
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw NetworkError.server(code: httpResponse.statusCode, description: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
        }
    }
}
