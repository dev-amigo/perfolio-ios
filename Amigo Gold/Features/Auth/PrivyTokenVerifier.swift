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
        let n: String
        let e: String
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
        guard segments.count == 3 else { throw PrivyTokenVerifierError.invalidTokenFormat }

        guard
            let headerData = Data(base64URLEncoded: String(segments[0])),
            let signatureData = Data(base64URLEncoded: String(segments[2]))
        else {
            throw PrivyTokenVerifierError.decodingFailed
        }

        let header = try JSONDecoder().decode(JWTHeader.self, from: headerData)
        guard header.alg.uppercased() == "RS256" else { throw PrivyTokenVerifierError.unsupportedAlgorithm }

        let jwk = try await key(for: header.kid)
        let publicKey = try buildPublicKey(from: jwk)

        let signedInput = Data("\(segments[0]).\(segments[1])".utf8)
        guard SecKeyIsAlgorithmSupported(publicKey, .verify, .rsaSignatureMessagePKCS1v15SHA256) else {
            throw PrivyTokenVerifierError.unsupportedAlgorithm
        }

        var error: Unmanaged<CFError>?
        let verified = SecKeyVerifySignature(
            publicKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            signedInput as CFData,
            signatureData as CFData,
            &error
        )

        if !verified {
            if let err = error?.takeRetainedValue() {
                throw err
            } else {
                throw PrivyTokenVerifierError.signatureInvalid
            }
        }
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

        let (data, response) = try await session.data(from: configuration.privyJWKSURL)
        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            throw PrivyTokenVerifierError.jwksFetchFailed
        }

        let jwks = try JSONDecoder().decode(JWKSResponse.self, from: data)
        keyCache = Dictionary(uniqueKeysWithValues: jwks.keys.map { ($0.kid, $0) })
        lastRefresh = Date()
    }

    private func buildPublicKey(from jwk: JWK) throws -> SecKey {
        if let algorithm = jwk.alg, algorithm.uppercased() != "RS256" {
            throw PrivyTokenVerifierError.unsupportedAlgorithm
        }
        guard jwk.kty.uppercased() == "RSA" else { throw PrivyTokenVerifierError.unsupportedAlgorithm }
        guard
            let modulus = Data(base64URLEncoded: jwk.n),
            let exponent = Data(base64URLEncoded: jwk.e)
        else {
            throw PrivyTokenVerifierError.decodingFailed
        }

        let keyData = rsaPublicKeyData(modulus: modulus, exponent: exponent)
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: modulus.count * 8,
        ]

        guard let key = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, nil) else {
            throw PrivyTokenVerifierError.keyCreationFailed
        }

        return key
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
