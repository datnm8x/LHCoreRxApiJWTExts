import Foundation

/*** Encode a set of claims
 - parameter claims: The set of claims
 - parameter algorithm: The algorithm to sign the payload with
 - returns: The JSON web token as a String
 */
public func JWTencode(claims: JWTClaimSet, algorithm: JWTAlgorithm, headers: [String: String]? = nil) -> String {
  func encodeJSON(_ payload: [String: Any]) -> String? {
    if let data = try? JSONSerialization.data(withJSONObject: payload) {
      return JWTbase64encode(data)
    }

    return nil
  }

  var headers = headers ?? [:]
  if !headers.keys.contains("typ") {
    headers["typ"] = "JWT"
  }
  headers["alg"] = algorithm.description

  let header = encodeJSON(headers)!
  let payload = encodeJSON(claims.claims)!
  let signingInput = "\(header).\(payload)"
  let signature = algorithm.sign(signingInput)
  return "\(signingInput).\(signature)"
}

/*** Encode a dictionary of claims
 - parameter claims: The dictionary of claims
 - parameter algorithm: The algorithm to sign the payload with
 - returns: The JSON web token as a String
 */
public func JWTencode(claims: [String: Any], algorithm: JWTAlgorithm, headers: [String: String]? = nil) -> String {
  return JWTencode(claims: JWTClaimSet(claims: claims), algorithm: algorithm, headers: headers)
}


/// Encode a set of claims using the builder pattern
public func JWTencode(_ algorithm: JWTAlgorithm, closure: ((JWTClaimSetBuilder) -> Void)) -> String {
  let builder = JWTClaimSetBuilder()
  closure(builder)
  return JWTencode(claims: builder.claims, algorithm: algorithm)
}

