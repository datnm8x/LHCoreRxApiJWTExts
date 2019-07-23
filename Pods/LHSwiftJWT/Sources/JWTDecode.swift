import Foundation


/// Failure reasons from decoding a JWT
public enum JWTInvalidToken: CustomStringConvertible, Error {
  /// Decoding the JWT itself failed
  case decodeError(String)

  /// The JWT uses an unsupported algorithm
  case invalidAlgorithm

  /// The issued claim has expired
  case expiredSignature

  /// The issued claim is for the future
  case immatureSignature

  /// The claim is for the future
  case invalidIssuedAt

  /// The audience of the claim doesn't match
  case invalidAudience

  /// The issuer claim failed to verify
  case invalidIssuer

  /// Returns a readable description of the error
  public var description: String {
    switch self {
    case .decodeError(let error):
      return "Decode Error: \(error)"
    case .invalidIssuer:
      return "Invalid Issuer"
    case .expiredSignature:
      return "Expired Signature"
    case .immatureSignature:
      return "The token is not yet valid (not before claim)"
    case .invalidIssuedAt:
      return "Issued at claim (iat) is in the future"
    case .invalidAudience:
      return "Invalid Audience"
    case .invalidAlgorithm:
      return "Unsupported algorithm or incorrect key"
    }
  }
}


/// Decode a JWT
public func JWTdecode(_ jwt: String, algorithms: [JWTAlgorithm], verify: Bool = true, audience: String? = nil, issuer: String? = nil, leeway: TimeInterval = 0) throws -> JWTClaimSet {
  let (header, claims, signature, signatureInput) = try JWTload(jwt)

  if verify {
    try claims.validate(audience: audience, issuer: issuer, leeway: leeway)
    try JWTverifySignature(algorithms, header: header, signingInput: signatureInput, signature: signature)
  }

  return claims
}

/// Decode a JWT
public func JWTdecode(_ jwt: String, algorithm: JWTAlgorithm, verify: Bool = true, audience: String? = nil, issuer: String? = nil, leeway: TimeInterval = 0) throws -> JWTClaimSet {
  return try JWTdecode(jwt, algorithms: [algorithm], verify: verify, audience: audience, issuer: issuer, leeway: leeway)
}

// MARK: Parsing a JWT

func JWTload(_ jwt: String) throws -> (header: JWTJOSEHeader, payload: JWTClaimSet, signature: Data, signatureInput: String) {
  let segments = jwt.components(separatedBy: ".")
  if segments.count != 3 {
    throw JWTInvalidToken.decodeError("Not enough segments")
  }

  let headerSegment = segments[0]
  let payloadSegment = segments[1]
  let signatureSegment = segments[2]
  let signatureInput = "\(headerSegment).\(payloadSegment)"

  guard let headerData = JWTbase64decode(headerSegment) else {
    throw JWTInvalidToken.decodeError("Header is not correctly encoded as base64")
  }

  let header = (try? JSONSerialization.jsonObject(with: headerData, options: JSONSerialization.ReadingOptions(rawValue: 0))) as? JWTPayload
  if header == nil {
    throw JWTInvalidToken.decodeError("Invalid header")
  }

  let payloadData = JWTbase64decode(payloadSegment)
  if payloadData == nil {
    throw JWTInvalidToken.decodeError("Payload is not correctly encoded as base64")
  }

  let payload = (try? JSONSerialization.jsonObject(with: payloadData!, options: JSONSerialization.ReadingOptions(rawValue: 0))) as? JWTPayload
  if payload == nil {
    throw JWTInvalidToken.decodeError("Invalid payload")
  }

  guard let signature = JWTbase64decode(signatureSegment) else {
    throw JWTInvalidToken.decodeError("Signature is not correctly encoded as base64")
  }

  return (header: JWTJOSEHeader(parameters: header!), payload: JWTClaimSet(claims: payload!), signature: signature, signatureInput: signatureInput)
}

// MARK: Signature Verification

func JWTverifySignature(_ algorithms: [JWTAlgorithm], header: JWTJOSEHeader, signingInput: String, signature: Data) throws {
  guard let alg = header.algorithm else {
    throw JWTInvalidToken.decodeError("Missing Algorithm")
  }

  let verifiedAlgorithms = algorithms
    .filter { algorithm in algorithm.description == alg }
    .filter { algorithm in algorithm.verify(signingInput, signature: signature) }

  if verifiedAlgorithms.isEmpty {
    throw JWTInvalidToken.invalidAlgorithm
  }
}
