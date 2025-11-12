import XCTest
@testable import Amigo_Gold

final class PrivyTokenVerifierTests: XCTestCase {
    private var verifier: PrivyTokenVerifier!
    private var environment: EnvironmentConfiguration!
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        environment = EnvironmentConfiguration(
            environment: .development,
            apiBaseURL: URL(string: "https://dev-api.amigogold.com")!,
            privyAppID: "cmhvskgil00nvky0cb6rjejrs",
            privyAppClientID: "client-WY6SX56F52MtzFqDzgL6jxdNAfpyL3kdY77zMdG4FgS2J",
            deepLinkScheme: "amigogold-dev",
            privyJWKSURL: URL(string: "https://auth.privy.io/api/v1/apps/cmhvskgil00nvky0cb6rjejrs/jwks.json")!,
            defaultOAuthProvider: "google",
            featureFlags: [],
            networkHeaders: [:]
        )
        verifier = PrivyTokenVerifier(configuration: environment, session: session)
        MockURLProtocol.requestHandler = nil
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        verifier = nil
        session = nil
        environment = nil
        super.tearDown()
    }

    func testVerifyRejectsInvalidTokenFormat() async {
        await XCTAssertThrowsErrorAsync(try await verifier.verify(accessToken: "invalid-token")) { error in
            guard let error = error as? PrivyTokenVerifierError else {
                XCTFail("Unexpected error \(error)")
                return
            }
            XCTAssertEqual(error, PrivyTokenVerifierError.invalidTokenFormat)
        }
    }

    func testVerifyRejectsUnsupportedAlgorithm() async {
        let token = Self.makeJWT(algorithm: "HS256", kid: "kid-123")
        await XCTAssertThrowsErrorAsync(try await verifier.verify(accessToken: token)) { error in
            guard let error = error as? PrivyTokenVerifierError else {
                XCTFail("Unexpected error \(error)")
                return
            }
            XCTAssertEqual(error, PrivyTokenVerifierError.unsupportedAlgorithm)
        }
    }

    func testVerifyFailsWhenKeyMissingFromJWKS() async {
        let expectation = expectation(description: "JWKS requested")
        MockURLProtocol.requestHandler = { request in
            expectation.fulfill()
            let json = Self.makeJWKS(kid: "different-kid")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        let token = Self.makeJWT(algorithm: "RS256", kid: "unknown-kid")
        await XCTAssertThrowsErrorAsync(try await verifier.verify(accessToken: token)) { error in
            guard let error = error as? PrivyTokenVerifierError else {
                XCTFail("Unexpected error \(error)")
                return
            }
            XCTAssertEqual(error, PrivyTokenVerifierError.missingKey)
        }
        await fulfillment(of: [expectation], timeout: 1)
    }

    func testVerifyFailsWhenJWKSFetchFails() async {
        let expectation = expectation(description: "JWKS requested")
        MockURLProtocol.requestHandler = { request in
            expectation.fulfill()
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let token = Self.makeJWT(algorithm: "RS256", kid: "any")
        await XCTAssertThrowsErrorAsync(try await verifier.verify(accessToken: token)) { error in
            guard let error = error as? PrivyTokenVerifierError else {
                XCTFail("Unexpected error \(error)")
                return
            }
            XCTAssertEqual(error, PrivyTokenVerifierError.jwksFetchFailed)
        }
        await fulfillment(of: [expectation], timeout: 1)
    }
}

private extension PrivyTokenVerifierTests {
    static func makeJWT(algorithm: String, kid: String) -> String {
        let header = ["alg": algorithm, "kid": kid]
        let payload = ["sub": "user"]
        let signature = Data([0x00, 0x01])

        let headerSegment = base64URLEncode(data: try! JSONSerialization.data(withJSONObject: header))
        let payloadSegment = base64URLEncode(data: try! JSONSerialization.data(withJSONObject: payload))
        let signatureSegment = base64URLEncode(data: signature)
        return [headerSegment, payloadSegment, signatureSegment].joined(separator: ".")
    }

    static func makeJWKS(kid: String) -> Data {
        let mockKey: [String: Any] = [
            "kty": "RSA",
            "kid": kid,
            "use": "sig",
            "alg": "RS256",
            "n": "sXchKx9qsVr91xqB3pij77vzAeVX1DJ7tY8DbDeihdj1x5Dmi50lQjBqFaUG2RgxN6E466zvWXTjhBMWrMUR3pvN8MPvMXxMvmXrKEBmRq6u40qCMgfHdCqkfNNpJBWlAbIYW/W2PASi6DPd7OJbRRqtD9h5pz50jd0vZk90un0nLBKBPXn1HULICwhf66A1VpzwuNFuIBqmoeZaZX6mE6xPD58Ll35H0TADaBrZEcD3xKhsR4HIX66vepQP9en5ZaY1f3T5iAG2wE8xmPKzW0fvkYlCYwH14r2raXIiQunlslqY5T2r8j04YfGLwRo_-es-sxFDXL9uBeb5GsyhQ",
            "e": "AQAB",
        ]
        let jwks = ["keys": [mockKey]]
        return try! JSONSerialization.data(withJSONObject: jwks)
    }

    static func base64URLEncode(data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension XCTestCase {
    func XCTAssertThrowsErrorAsync<T>(
        _ expression: @autoclosure @escaping () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail(message(), file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }
}
