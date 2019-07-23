import Foundation

func JWTvalidateDate(_ payload: JWTPayload, key: String, comparison: ComparisonResult, leeway: TimeInterval = 0, failure: JWTInvalidToken, decodeError: String) throws {
  if payload[key] == nil {
    return
  }

  guard let date = JWTextractDate(payload: payload, key: key) else {
    throw JWTInvalidToken.decodeError(decodeError)
  }
	
  if date.compare(Date().addingTimeInterval(leeway)) == comparison {
    throw failure
  }
}

fileprivate func JWTextractDate(payload: JWTPayload, key: String) -> Date? {
  if let timestamp = payload[key] as? TimeInterval {
    return Date(timeIntervalSince1970: timestamp)
  }

  if let timestamp = payload[key] as? Int {
    return Date(timeIntervalSince1970: Double(timestamp))
  }

  if let timestampString = payload[key] as? String, let timestamp = Double(timestampString) {
    return Date(timeIntervalSince1970: timestamp)
  }

  return nil
}
