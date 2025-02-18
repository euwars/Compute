//
//  JWT.swift
//  
//
//  Created by Andrew Barba on 11/27/22.
//

public struct JWT: Sendable {

    public let token: String

    public let algorithm: Algorithm

    public let header: [String: Sendable]

    public let payload: [String: Sendable]

    public let signature: Data

    public func claim(name: String) -> Claim {
        return .init(value: payload[name])
    }

    public subscript(key: String) -> Claim {
        return claim(name: key)
    }

    public init(token: String) throws {
        // Verify token parts
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            throw JWTError.invalidToken
        }

        // Parse header
        let header = try decodeJWTPart(parts[0])

        // Parse algorithm
        guard let alg = header["alg"] as? String, let algorithm = Algorithm(rawValue: alg) else {
            throw JWTError.unsupportedAlgorithm
        }

        // Parse payload
        let payload = try decodeJWTPart(parts[1])

        // Parse signature
        let signature = try base64UrlDecode(parts[2])

        self.header = header
        self.payload = payload
        self.signature = signature
        self.algorithm = algorithm
        self.token = token
    }

    public init(
        claims: [String: Any],
        secret: String,
        algorithm: Algorithm = .hs256,
        issuedAt: Date = .init(),
        expiresAt: Date? = nil,
        issuer: String? = nil,
        subject: String? = nil,
        identifier: String? = nil
    ) throws {
        let header: [String: Any] = [
            "alg": algorithm.rawValue,
            "typ": "JWT"
        ]

        var properties: [String: Any] = [
            "iat": floor(issuedAt.timeIntervalSince1970)
        ]

        if let expiresAt {
            properties["exp"] = ceil(expiresAt.timeIntervalSince1970)
        }

        if let subject {
            properties["sub"] = subject
        }

        if let issuer {
            properties["iss"] = issuer
        }

        if let identifier {
            properties["jti"] = identifier
        }

        let payload = claims.merging(properties, uniquingKeysWith: { $1 })

        let _header = try encodeJWTPart(header)

        let _payload = try encodeJWTPart(payload)

        let input = "\(_header).\(_payload)"

        let signature = try hmacSignature(input, secret: secret, using: algorithm)

        let _signature = try base64UrlEncode(signature)

        self.header = header
        self.payload = payload
        self.signature = signature
        self.algorithm = algorithm
        self.token = "\(_header).\(_payload).\(_signature)"
    }
}

extension JWT {

    public var expiresAt: Date? {
        claim(name: "exp").date
    }

    public var issuer: String? {
        claim(name: "iss").string
    }

    public var subject: String? {
        claim(name: "sub").string
    }

    public var audience: [String]? {
        claim(name: "aud").array
    }

    public var issuedAt: Date? {
        claim(name: "iat").date
    }

    public var notBefore: Date? {
        claim(name: "nbf").date
    }

    public var identifier: String? {
        claim(name: "jti").string
    }

    public var expired: Bool {
        guard let expiresAt = self.expiresAt else {
            return false
        }
        return Date() > expiresAt
    }
}

extension JWT {

    @discardableResult
    public func verify(
        key: String,
        using algorithm: Algorithm? = nil,
        issuer: String? = nil,
        subject: String? = nil,
        expiration: Bool = true
    ) throws -> Self {
        // Build input
        let input = token.components(separatedBy: ".").prefix(2).joined(separator: ".")

        // Ensure the signatures match
        try verifySignature(input, signature: signature, key: key, using: algorithm ?? self.algorithm)

        // Ensure the jwt is not expired
        if expiration, self.expired == true {
            throw JWTError.expiredToken
        }

        // Check for a matching issuer
        if let issuer, issuer != self.issuer {
            throw JWTError.invalidIssuer
        }

        // Check for a matching subject
        if let subject, subject != self.subject {
            throw JWTError.invalidSubject
        }

        return self
    }
}

extension JWT {
    public enum Algorithm: String, Sendable {
        case hs256 = "HS256"
        case hs384 = "HS384"
        case hs512 = "HS512"
        case es256 = "ES256"
        case es384 = "ES384"
        case es512 = "ES512"
    }
}

private func decodeJWTPart(_ value: String) throws -> [String: Any] {
    let bodyData = try base64UrlDecode(value)
    guard let json = try JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any] else {
        throw JWTError.invalidJSON
    }
    return json
}

private func encodeJWTPart(_ value: [String: Any]) throws -> String {
    let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    return try base64UrlEncode(data)
}

private func hmacSignature(_ input: String, secret: String, using algorithm: JWT.Algorithm) throws -> Data {
    switch algorithm {
    case .hs256:
        return Crypto.Auth.code(for: input, secret: secret, using: .sha256)
    case .hs384:
        return Crypto.Auth.code(for: input, secret: secret, using: .sha384)
    case .hs512:
        return Crypto.Auth.code(for: input, secret: secret, using: .sha512)
    case .es256:
        return try Crypto.ECDSA.signature(for: input, secret: secret, using: .p256)
    case .es384:
        return try Crypto.ECDSA.signature(for: input, secret: secret, using: .p384)
    case .es512:
        return try Crypto.ECDSA.signature(for: input, secret: secret, using: .p521)
    }
}

private func verifySignature(_ input: String, signature: Data, key: String, using algorithm: JWT.Algorithm) throws {
    let verified: Bool
    switch algorithm {
    case .es256:
        verified = try Crypto.ECDSA.verify(input, signature: signature, key: key, using: .p256)
    case .es384:
        verified = try Crypto.ECDSA.verify(input, signature: signature, key: key, using: .p384)
    case .es512:
        verified = try Crypto.ECDSA.verify(input, signature: signature, key: key, using: .p521)
    case .hs256:
        verified = Crypto.Auth.verify(input, signature: signature, secret: key, using: .sha256)
    case .hs384:
        verified = Crypto.Auth.verify(input, signature: signature, secret: key, using: .sha384)
    case .hs512:
        verified = Crypto.Auth.verify(input, signature: signature, secret: key, using: .sha512)
    }
    guard verified else {
        throw JWTError.invalidSignature
    }
}

private func base64UrlDecode(_ value: String) throws -> Data {
    var base64 = value
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    let length = Double(base64.lengthOfBytes(using: String.Encoding.utf8))
    let requiredLength = 4 * ceil(length / 4.0)
    let paddingLength = requiredLength - length
    if paddingLength > 0 {
        let padding = "".padding(toLength: Int(paddingLength), withPad: "=", startingAt: 0)
        base64 += padding
    }
    guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
        throw JWTError.invalidBase64URL
    }
    return data
}

private func base64UrlEncode(_ value: Data) throws -> String {
    return value
        .base64EncodedString()
        .trimmingCharacters(in: ["="])
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
}
