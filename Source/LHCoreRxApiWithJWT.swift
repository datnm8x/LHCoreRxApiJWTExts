//
//  LHCoreRxApiWithJWT.swift
//  LHCoreRxApiJWTExts iOS
//
//  Created by Dat Ng on 7/22/19.
//  Copyright © 2019 Lao Hac. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON
import RxSwift
import JSONWebToken

public typealias LHCoreJWTResults = (json: JSON?, result: String)

public extension LHCoreRxAPIService {
    // MARK: JSON JWT response ========================================================================
    
    static func rxRequestJWTEncoding(
        method apiMethod: HTTPMethod = .post,
        apiPath path: String,
        params parameters: LHCoreApiPayload? = nil,
        headers headerParams: LHCoreApiHeaders? = nil,
        secretKeyJWT: String = LHCoreRxAPIService.secretKeyJWT) -> Observable<LHCoreJWTResults> {
        if let params = parameters {
            do {
                let paramsEncode = try params.encoded(secretKey: secretKeyJWT)
                return rxRequestJWTEncoded(method: apiMethod, apiPath: path, encodedParam: paramsEncode, headers: headerParams, secretKeyJWT: secretKeyJWT)
            } catch let error {
                return Observable.create({ observer -> Disposable in
                    observer.onError(error)
                    return Disposables.create()
                })
            }
        } else {
            return rxRequestJWTEncoded(method: apiMethod, apiPath: path, headers: headerParams, secretKeyJWT: secretKeyJWT)
        }
    }
    
    static func rxRequestJWTEncoded(
        method apiMethod: HTTPMethod = .post,
        apiPath path: String,
        encodedParam parameters: LHCoreApiPayload? = nil,
        headers headerParams: LHCoreApiHeaders? = nil,
        secretKeyJWT: String = LHCoreRxAPIService.secretKeyJWT) -> Observable<LHCoreJWTResults> {
        
        let mergeHeaders = self.mergeDefaultHeaders(headerParams)
        let encoding: ParameterEncoding = apiMethod == .get ? URLEncoding.default : JSONEncoding.default
        
        return Observable.create({ observer -> Disposable in
            let dataRequest = Alamofire.request(path.fullUrlStringWithAPIBaseURL, method: apiMethod, parameters: parameters, encoding: encoding, headers: mergeHeaders)
                .validate(statusCode: 200..<LHCoreRxAPIService.validateStatusCode)
                .responseString(completionHandler: { (dataResponse) in
                    switch dataResponse.result {
                    case .success(let resultString):
                        do {
                            let payload = try resultString.decodeJWT(secretKey: secretKeyJWT)
                            observer.onNext((json: JSON(payload), result: resultString))
                        } catch {
                            observer.onNext((json: nil, result: resultString))
                        }
                        
                    case .failure(let error):
                        observer.onError(dataResponse.errorResponseWithError(error))
                    }
                    
                    observer.onCompleted()
                })
            
            dataRequest.doLogCURL()
            
            return Disposables.create()
        })
    }
}

public extension LHCoreApiPayload {
    var encoded: LHCoreApiPayload {
        do {
            return try encoded()
        } catch {
            print("Failed to encode JWT: \(error)")
            return self
        }
    }
    
    func encoded(secretKey: String = LHCoreRxAPIService.secretKeyJWT) throws -> LHCoreApiPayload {
        do {
            guard let secretData = secretKey.data(using: .utf8) else {
                throw NSError(domain: "LHCoreRxAPIService.decodeJWT", code: -1, userInfo: ["message": "SecretKey data is invalid"])
            }
            
            let encodedString = JWTencode(claims: ClaimSet(claims: self), algorithm: Algorithm.hs256(secretData))
            return ["value": encodedString]
        } catch let error {
            throw error
        }
    }
}

public extension String {
    var decodeJWT: LHCoreApiPayload? {
        do {
            return try decodeJWT()
        } catch {
            print("Failed to decode JWT: \(error)")
            return nil
        }
    }
    
    func decodeJWT(secretKey: String = LHCoreRxAPIService.secretKeyJWT) throws -> LHCoreApiPayload {
        do {
            guard let secretData = secretKey.data(using: .utf8) else {
                throw NSError(domain: "LHCoreRxAPIService.decodeJWT", code: -1, userInfo: ["message": "SecretKey data is invalid"])
            }
            
            let jwtString = (self as NSString).replacingOccurrences(of: "\"", with: "")
            let claims: ClaimSet = try JWTdecode(jwtString, algorithm: .hs256(secretData))
            return claims.claims
        } catch let error {
            throw error
        }
    }
}
