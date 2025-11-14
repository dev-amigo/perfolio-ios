import Foundation

/// Client for making RPC calls through Privy's REST API
/// Docs: https://docs.privy.io/controls/dashboard/intents#via-the-rest-api
actor PrivyRPCClient {
    private struct RPCRequest: Encodable {
        let method: String
        let params: [AnyCodable]
    }
    
    private struct RPCResponse: Decodable {
        let result: AnyCodable?
        let error: RPCError?
    }
    
    private struct RPCError: Decodable {
        let code: Int
        let message: String
    }
    
    // AnyCod able for dynamic JSON
    struct AnyCodable: Codable {
        let value: Any
        
        init(_ value: Any) {
            self.value = value
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            
            if let string = value as? String {
                try container.encode(string)
            } else if let int = value as? Int {
                try container.encode(int)
            } else if let double = value as? Double {
                try container.encode(double)
            } else if let bool = value as? Bool {
                try container.encode(bool)
            } else if let array = value as? [Any] {
                try container.encode(array.map { AnyCodable($0) })
            } else if let dict = value as? [String: Any] {
                try container.encode(dict.mapValues { AnyCodable($0) })
            } else if value is NSNull {
                try container.encodeNil()
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            
            if container.decodeNil() {
                value = NSNull()
            } else if let string = try? container.decode(String.self) {
                value = string
            } else if let int = try? container.decode(Int.self) {
                value = int
            } else if let double = try? container.decode(Double.self) {
                value = double
            } else if let bool = try? container.decode(Bool.self) {
                value = bool
            } else if let array = try? container.decode([AnyCodable].self) {
                value = array.map { $0.value }
            } else if let dict = try? container.decode([String: AnyCodable].self) {
                value = dict.mapValues { $0.value }
            } else {
                value = NSNull()
            }
        }
    }
    
    private let apiBaseURL: String
    private let walletId: String
    private let accessToken: String
    private let session: URLSession
    
    init?(session: URLSession = .shared) {
        // Get configuration from Info.plist
        guard let apiBaseURL = Bundle.main.object(forInfoDictionaryKey: "AGPrivyAPIBaseURL") as? String,
              !apiBaseURL.isEmpty else {
            AppLogger.log("⚠️ Privy API Base URL not configured", category: "web3")
            return nil
        }
        
        // Get wallet ID and access token from storage
        guard let walletId = UserDefaults.standard.string(forKey: "userWalletId"),
              let accessToken = UserDefaults.standard.string(forKey: "privyAccessToken") else {
            AppLogger.log("⚠️ Wallet ID or access token not available", category: "web3")
            return nil
        }
        
        self.apiBaseURL = apiBaseURL
        self.walletId = walletId
        self.accessToken = accessToken
        self.session = session
        
        AppLogger.log("✅ PrivyRPCClient initialized", category: "web3")
        AppLogger.log("   API Base: \(apiBaseURL)", category: "web3")
        AppLogger.log("   Wallet ID: \(walletId.prefix(10))...", category: "web3")
    }
    
    /// Make an RPC call through Privy's REST API
    /// Endpoint: POST /wallets/{wallet_id}/rpc
    func call(method: String, params: [Any]) async throws -> Any {
        // Build endpoint URL
        let endpoint = "\(apiBaseURL)/wallets/\(walletId)/rpc"
        
        guard let url = URL(string: endpoint) else {
            throw Web3Error.invalidURL
        }
        
        AppLogger.log("Privy RPC call: \(method)", category: "web3")
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        // Build request body
        let rpcRequest = RPCRequest(
            method: method,
            params: params.map { AnyCodable($0) }
        )
        
        request.httpBody = try JSONEncoder().encode(rpcRequest)
        
        // Make request
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Web3Error.invalidResponse
        }
        
        // Log response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            AppLogger.log("Privy RPC response (\(httpResponse.statusCode)): \(responseString)", category: "web3")
        } else {
            AppLogger.log("Privy RPC response (\(httpResponse.statusCode)): [binary data]", category: "web3")
        }
        
        // Log full request for 405 errors
        if httpResponse.statusCode == 405 {
            AppLogger.log("⚠️ HTTP 405 Method Not Allowed", category: "web3")
            AppLogger.log("   Endpoint: \(endpoint)", category: "web3")
            AppLogger.log("   Method: POST", category: "web3")
            AppLogger.log("   Headers: Authorization: Bearer [token], Content-Type: application/json", category: "web3")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw Web3Error.invalidResponse
        }
        
        // Parse response
        let rpcResponse = try JSONDecoder().decode(RPCResponse.self, from: data)
        
        if let error = rpcResponse.error {
            throw Web3Error.rpcError(code: error.code, message: error.message)
        }
        
        guard let result = rpcResponse.result?.value else {
            throw Web3Error.invalidResponse
        }
        
        AppLogger.log("Privy RPC call successful: \(method)", category: "web3")
        return result
    }
}

