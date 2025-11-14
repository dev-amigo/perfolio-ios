import Foundation
import Security

enum PrivyTokenVerifierError: LocalizedError {
    case invalidTokenFormat
    case unsupportedAlgorithm
    case missingKey
    case signatureInvalid
    case keyCreationFailed
    case jwksFetchFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidTokenFormat:
            return "Access token is not a valid JWT."
        case .unsupportedAlgorithm:
            return "Unsupported signing algorithm."
        case .missingKey:
            return "Unable to find matching signing key."
        case .signatureInvalid:
            return "Access token signature is invalid."
        case .keyCreationFailed:
            return "Failed to build RSA key from JWKS."
        case .jwksFetchFailed:
            return "Unable to fetch JWKS from Privy."
        case .decodingFailed:
            return "Failed to decode token or JWKS data."
        }
    }
}

extension PrivyTokenVerifierError: Equatable {}

actor PrivyTokenVerifier {
    private struct JWKSResponse: Decodable {
        let keys: [JWK]
    }

    private struct JWK: Decodable {
        let kty: String
        let kid: String
        let alg: String?
        let use: String?
        let crv: String?  // For EC keys
        let x: String?    // For EC keys
        let y: String?    // For EC keys
        let n: String?    // For RSA keys
        let e: String?    // For RSA keys
    }

    private struct JWTHeader: Decodable {
        let alg: String
        let kid: String
    }

    private let configuration: EnvironmentConfiguration
    private let session: URLSession
    private var keyCache: [String: JWK] = [:]
    private var lastRefresh: Date?
    private let cacheTTL: TimeInterval = 60 * 10

    init(configuration: EnvironmentConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func verify(accessToken: String) async throws {
        let segments = accessToken.split(separator: ".")
        guard segments.count == 3 else {
            AppLogger.log("Token verification failed: Invalid format (segments: \(segments.count))", category: "auth")
            throw PrivyTokenVerifierError.invalidTokenFormat
        }

        guard
            let headerData = Data(base64URLEncoded: String(segments[0])),
            let signatureData = Data(base64URLEncoded: String(segments[2]))
        else {
            AppLogger.log("Token verification failed: Base64 decoding failed", category: "auth")
            throw PrivyTokenVerifierError.decodingFailed
        }

        let header = try JSONDecoder().decode(JWTHeader.self, from: headerData)
        AppLogger.log("Token header - alg: \(header.alg), kid: \(header.kid)", category: "auth")
        
        let algorithm = header.alg.uppercased()
        guard algorithm == "RS256" || algorithm == "ES256" else {
            AppLogger.log("Token verification failed: Unsupported algorithm '\(header.alg)'", category: "auth")
            throw PrivyTokenVerifierError.unsupportedAlgorithm
        }

        let jwk = try await key(for: header.kid)
        AppLogger.log("Found JWK for kid: \(header.kid), alg: \(jwk.alg ?? "none"), kty: \(jwk.kty)", category: "auth")
        
        let publicKey = try buildPublicKey(from: jwk, algorithm: algorithm)
        AppLogger.log("Public key created successfully", category: "auth")

        let signedInput = Data("\(segments[0]).\(segments[1])".utf8)
        
        // Choose the right verification algorithm based on token type
        let secAlgorithm: SecKeyAlgorithm
        if algorithm == "ES256" {
            secAlgorithm = .ecdsaSignatureMessageX962SHA256
        } else {
            secAlgorithm = .rsaSignatureMessagePKCS1v15SHA256
        }
        
        let isSupported = SecKeyIsAlgorithmSupported(publicKey, .verify, secAlgorithm)
        AppLogger.log("\(algorithm) algorithm supported: \(isSupported)", category: "auth")
        
        guard isSupported else {
            AppLogger.log("Token verification failed: Algorithm not supported by SecKey", category: "auth")
            throw PrivyTokenVerifierError.unsupportedAlgorithm
        }

        var error: Unmanaged<CFError>?
        let verified = SecKeyVerifySignature(
            publicKey,
            secAlgorithm,
            signedInput as CFData,
            signatureData as CFData,
            &error
        )

        if !verified {
            if let err = error?.takeRetainedValue() {
                AppLogger.log("Token verification failed: \(err)", category: "auth")
                throw err
            } else {
                AppLogger.log("Token verification failed: Invalid signature", category: "auth")
                throw PrivyTokenVerifierError.signatureInvalid
            }
        }
        
        AppLogger.log("Token verification succeeded!", category: "auth")
    }

    private func key(for kid: String) async throws -> JWK {
        if let cached = keyCache[kid], let lastRefresh, Date().timeIntervalSince(lastRefresh) < cacheTTL {
            return cached
        }

        try await refreshKeys()

        if let cached = keyCache[kid] {
            return cached
        }

        throw PrivyTokenVerifierError.missingKey
    }

    private func refreshKeys() async throws {
        if let lastRefresh, Date().timeIntervalSince(lastRefresh) < cacheTTL, !keyCache.isEmpty {
            return
        }

        AppLogger.log("Fetching JWKS from: \(configuration.privyJWKSURL.absoluteString)", category: "auth")
        
        let (data, response) = try await session.data(from: configuration.privyJWKSURL)
        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            AppLogger.log("JWKS fetch failed: HTTP status \((response as? HTTPURLResponse)?.statusCode ?? -1)", category: "auth")
            throw PrivyTokenVerifierError.jwksFetchFailed
        }

        let jwks = try JSONDecoder().decode(JWKSResponse.self, from: data)
        AppLogger.log("JWKS fetched successfully: \(jwks.keys.count) keys", category: "auth")
        keyCache = Dictionary(uniqueKeysWithValues: jwks.keys.map { ($0.kid, $0) })
        lastRefresh = Date()
    }

    private func buildPublicKey(from jwk: JWK, algorithm: String) throws -> SecKey {
        let keyType = jwk.kty.uppercased()
        
        if keyType == "EC" {
            // Elliptic Curve key (ES256)
            AppLogger.log("Building EC public key for ES256", category: "auth")
            guard let crv = jwk.crv, crv == "P-256" else {
                AppLogger.log("buildPublicKey failed: EC curve '\(jwk.crv ?? "none")' not supported", category: "auth")
                throw PrivyTokenVerifierError.unsupportedAlgorithm
            }
            guard
                let xData = jwk.x.flatMap({ Data(base64URLEncoded: $0) }),
                let yData = jwk.y.flatMap({ Data(base64URLEncoded: $0) })
            else {
                AppLogger.log("buildPublicKey failed: Unable to decode EC x or y coordinates", category: "auth")
                throw PrivyTokenVerifierError.decodingFailed
            }
            
            // EC public key format: 0x04 + x-coordinate + y-coordinate
            var keyData = Data([0x04])
            keyData.append(xData)
            keyData.append(yData)
            
            let attributes: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
                kSecAttrKeySizeInBits as String: 256
            ]
            
            guard let key = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, nil) else {
                AppLogger.log("buildPublicKey failed: SecKeyCreateWithData returned nil for EC key", category: "auth")
                throw PrivyTokenVerifierError.keyCreationFailed
            }
            
            AppLogger.log("buildPublicKey succeeded: Created EC public key", category: "auth")
            return key
            
        } else if keyType == "RSA" {
            // RSA key (RS256)
            AppLogger.log("Building RSA public key for RS256", category: "auth")
            guard
                let modulus = jwk.n.flatMap({ Data(base64URLEncoded: $0) }),
                let exponent = jwk.e.flatMap({ Data(base64URLEncoded: $0) })
            else {
                AppLogger.log("buildPublicKey failed: Unable to decode RSA modulus or exponent", category: "auth")
                throw PrivyTokenVerifierError.decodingFailed
            }

            let keyData = rsaPublicKeyData(modulus: modulus, exponent: exponent)
            let attributes: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
                kSecAttrKeySizeInBits as String: modulus.count * 8,
            ]

            guard let key = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, nil) else {
                AppLogger.log("buildPublicKey failed: SecKeyCreateWithData returned nil for RSA key", category: "auth")
                throw PrivyTokenVerifierError.keyCreationFailed
            }

            AppLogger.log("buildPublicKey succeeded: Created RSA public key", category: "auth")
            return key
        } else {
            AppLogger.log("buildPublicKey failed: Key type '\(keyType)' not supported", category: "auth")
            throw PrivyTokenVerifierError.unsupportedAlgorithm
        }
    }

    private func rsaPublicKeyData(modulus: Data, exponent: Data) -> Data {
        let modulusInteger = derEncodeInteger(modulus)
        let exponentInteger = derEncodeInteger(exponent)
        let sequencePayload = modulusInteger + exponentInteger
        let sequence = derEncode(tag: 0x30, data: sequencePayload)

        let algorithmIdentifier: [UInt8] = [
            0x30, 0x0d, 0x06, 0x09,
            0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01,
            0x05, 0x00,
        ]

        let bitString = derEncode(tag: 0x03, data: Data([0x00]) + sequence)

        return derEncode(tag: 0x30, data: Data(algorithmIdentifier) + bitString)
    }

    private func derEncode(tag: UInt8, data: Data) -> Data {
        var encoded = Data([tag])
        encoded.append(derLength(of: data.count))
        encoded.append(data)
        return encoded
    }

    private func derEncodeInteger(_ data: Data) -> Data {
        var bytes = data
        if bytes.first ?? 0 >= 0x80 {
            bytes.insert(0x00, at: 0)
        }
        return derEncode(tag: 0x02, data: bytes)
    }

    private func derLength(of length: Int) -> Data {
        if length < 0x80 {
            return Data([UInt8(length)])
        }

        var value = length
        var bytes: [UInt8] = []
        while value > 0 {
            bytes.insert(UInt8(value & 0xff), at: 0)
            value >>= 8
        }

        var data = Data([0x80 | UInt8(bytes.count)])
        data.append(contentsOf: bytes)
        return data
    }
}
