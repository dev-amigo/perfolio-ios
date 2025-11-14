import Foundation

enum Web3Error: LocalizedError {
    case invalidURL
    case invalidResponse
    case rpcError(code: Int, message: String)
    case decodingFailed
    case allRPCsFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid RPC URL"
        case .invalidResponse:
            return "Invalid response from RPC"
        case .rpcError(let code, let message):
            return "RPC Error \(code): \(message)"
        case .decodingFailed:
            return "Failed to decode RPC response"
        case .allRPCsFailed:
            return "All RPC endpoints failed"
        }
    }
}

actor Web3Client {
    private struct RPCRequest: Encodable {
        let jsonrpc = "2.0"
        let id = 1
        let method: String
        let params: [AnyCodable]
    }
    
    private struct RPCResponse: Decodable {
        let jsonrpc: String
        let id: Int
        let result: AnyCodable?
        let error: RPCError?
    }
    
    private struct RPCError: Decodable {
        let code: Int
        let message: String
    }
    
    // AnyCodable wrapper for encoding/decoding dynamic JSON
    private struct AnyCodable: Codable {
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
            } else {
                throw EncodingError.invalidValue(value, EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Invalid value type"
                ))
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
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode value"
                )
            }
        }
    }
    
    private let primaryRPC: String
    private let fallbackRPC: String
    private let session: URLSession
    
    init(
        primaryRPC: String? = nil,
        fallbackRPC: String? = nil,
        session: URLSession = .shared
    ) {
        // Use Privy RPC as primary (with gas sponsorship support)
        let privyRPCURL = Bundle.main.object(forInfoDictionaryKey: "AGPrivyRPCURL") as? String ?? ""
        let configuredFallback = Bundle.main.object(forInfoDictionaryKey: "AGEthereumRPCFallback") as? String ?? ""
        let defaultFallback = "https://ethereum.publicnode.com"
        
        // Set primary RPC (Privy preferred)
        if !privyRPCURL.isEmpty {
            self.primaryRPC = primaryRPC ?? privyRPCURL
            AppLogger.log("🔗 Web3Client initialized with Privy RPC", category: "web3")
            AppLogger.log("   Primary: \(privyRPCURL)", category: "web3")
        } else {
            let fallbackToUse = !configuredFallback.isEmpty ? configuredFallback : defaultFallback
            self.primaryRPC = primaryRPC ?? fallbackToUse
            AppLogger.log("⚠️ Privy RPC not configured, using fallback", category: "web3")
        }
        
        // Set fallback RPC (LlamaRPC or public node)
        self.fallbackRPC = fallbackRPC ?? (!configuredFallback.isEmpty ? configuredFallback : defaultFallback)
        AppLogger.log("   Fallback: \(self.fallbackRPC)", category: "web3")
        
        self.session = session
        
        // Gas sponsorship info
        AppLogger.log("💡 Privy RPC includes gas sponsorship for transactions", category: "web3")
    }
    
    /// Make a generic RPC call with automatic fallback
    func call(method: String, params: [Any]) async throws -> Any {
        // Try primary RPC first
        do {
            let result = try await makeRPCCall(to: primaryRPC, method: method, params: params)
            AppLogger.log("RPC call successful (primary): \(method)", category: "web3")
            return result
        } catch {
            AppLogger.log("Primary RPC failed for \(method): \(error)", category: "web3")
            
            // Fallback to secondary RPC
            do {
                let result = try await makeRPCCall(to: fallbackRPC, method: method, params: params)
                AppLogger.log("RPC call successful (fallback): \(method)", category: "web3")
                return result
            } catch {
                AppLogger.log("Fallback RPC also failed for \(method): \(error)", category: "web3")
                throw Web3Error.allRPCsFailed
            }
        }
    }
    
    /// Make an eth_call to a contract
    func ethCall(to contractAddress: String, data: String, block: String = "latest") async throws -> String {
        let params: [Any] = [
            ["to": contractAddress, "data": data],
            block
        ]
        
        let result = try await call(method: "eth_call", params: params)
        guard let resultString = result as? String else {
            throw Web3Error.invalidResponse
        }
        
        return resultString
    }
    
    /// Get the current block number
    func getBlockNumber() async throws -> UInt64 {
        let result = try await call(method: "eth_blockNumber", params: [])
        guard let hexString = result as? String else {
            throw Web3Error.invalidResponse
        }
        
        // Remove "0x" prefix and convert hex to decimal
        let cleanHex = hexString.replacingOccurrences(of: "0x", with: "")
        guard let blockNumber = UInt64(cleanHex, radix: 16) else {
            throw Web3Error.decodingFailed
        }
        
        return blockNumber
    }
    
    private func makeRPCCall(to rpcURL: String, method: String, params: [Any]) async throws -> Any {
        guard let url = URL(string: rpcURL) else {
            throw Web3Error.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let rpcRequest = RPCRequest(
            method: method,
            params: params.map { AnyCodable($0) }
        )
        
        request.httpBody = try JSONEncoder().encode(rpcRequest)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw Web3Error.invalidResponse
        }
        
        let rpcResponse = try JSONDecoder().decode(RPCResponse.self, from: data)
        
        if let error = rpcResponse.error {
            throw Web3Error.rpcError(code: error.code, message: error.message)
        }
        
        guard let result = rpcResponse.result?.value else {
            throw Web3Error.invalidResponse
        }
        
        return result
    }
}

