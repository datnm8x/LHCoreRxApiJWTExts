//
//  LHCoreRxAPIService.swift
//  Base Utils
//
//  Created by Dat Ng on 2/23/18.
//  Copyright © 2018 datnm (laohac83x@gmail.com). All rights reserved.
//

import UIKit
import Foundation
import SwiftyJSON
import Alamofire
import AlamofireImage
import RxSwift

public let LHCoreErrorDomain: String = "LHCoreRxAPIService.AlamofireExt"

public struct LHCoreApiDefault {
    public static var startPage = 0
    public static var pageSize = 10
    public static var timeZone = 9
    public static var startId: Int64 = 0
    public static var nonItemId: Int64 = -1
}

// MARK: - Alamofire Manager for custom
public struct LHCoreErrorCodes {
    public static let unAuthorized = 401
    public static let forbidden = 403
    public static let notFound = 404
    
    public static let badURLStatusCode = -9001
    public static let emptyResponseData = -9002
    public static let unKnow = -9003
    public static let userCancel = -9004
    public static let hasRequesting = -9005
    public static let noMoreData = -9006
    public static let noFunction = -9007
}

// MARK: main class for LHAPIService base
public typealias LHCoreRxRequestCompletionHandler = (JSON, Error?) -> Void
public typealias LHCoreApiPayload = [String: Any]
public typealias LHCoreApiHeaders = [String: String]

open class LHCoreRxAPIService: NSObject {
    static public var apiBaseURLString: String = ""
    static public var enableCURLDebugLog: Bool = false
    static public var limitedCURLDebugLogLength: Int = 1024
    static public var defaultHeaders: [String: String]?
    static public var defaultRequestTimeout: TimeInterval = 60.0
    static public var defaultResourceTimeout: TimeInterval = 120.0
    static public var validateStatusCode: Int = 300
    static public var secretKeyJWT: String = ""
    
    static let disposeBag = DisposeBag()
    static public var mainScheduler: MainScheduler { return MainScheduler.instance }
    static public var bkgScheduler: SerialDispatchQueueScheduler = SerialDispatchQueueScheduler(qos: DispatchQoS.userInitiated)
    
    public static func config(customSSL: Bool = false, apiHost: String = "") {
        self.apiBaseURLString = apiHost
        SessionManager.default.session.configuration.timeoutIntervalForRequest = LHCoreRxAPIService.defaultRequestTimeout
        SessionManager.default.session.configuration.timeoutIntervalForResource = LHCoreRxAPIService.defaultResourceTimeout
        
        if customSSL {
            #if DEBUG
            print("LHAPIService: Custom SSL ...")
            #endif
            SessionManager.default.delegate.sessionDidReceiveChallenge = { session, challenge in
                var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
                var credential: URLCredential?
                
                if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                    disposition = URLSession.AuthChallengeDisposition.useCredential
                    credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
                } else {
                    if challenge.previousFailureCount > 0 {
                        disposition = .cancelAuthenticationChallenge
                    } else {
                        credential = session.configuration.urlCredentialStorage?.defaultCredential(for: challenge.protectionSpace)
                        if credential != nil {
                            disposition = .useCredential
                        }
                    }
                }
                return (disposition, credential)
            }
        }
    }
    
    // MARK: JSON response ========================================================================
    static public func doRequestJSON(
        method apiMethod: HTTPMethod = .get,
        apiPath path: String,
        params parameters: LHCoreApiPayload? = nil,
        headers headerParams: LHCoreApiHeaders? = nil,
        completion: LHCoreRxRequestCompletionHandler? = nil) {
        
        let mergeHeaders = self.mergeDefaultHeaders(headerParams)
        let encoding: ParameterEncoding = apiMethod == .get ? URLEncoding.default : JSONEncoding.default
        let dataRequest = Alamofire.request(path.fullUrlStringWithAPIBaseURL, method: apiMethod, parameters: parameters, encoding: encoding, headers: mergeHeaders)
            .validate(statusCode: 200..<LHCoreRxAPIService.validateStatusCode)
            .responseJSON { dataResponse in
                switch dataResponse.result {
                case .success(let resultData):
                    completion?(JSON(resultData), nil)
                case .failure(let error):
                    completion?(JSON(), dataResponse.errorResponseWithError(error))
                }
        }
        
        dataRequest.doLogCURL()
    }
    
    static public func doPostMultipartDataJSON(
        apiPath path: String,
        params parameters: LHCoreApiPayload? = nil,
        headers headerParams: LHCoreApiHeaders? = nil,
        multipartDatas multiDatas: [MultipartDataExt],
        completion: LHCoreRxRequestCompletionHandler? = nil) {
        
        let mergeHeaders = self.mergeDefaultHeaders(headerParams)
        Alamofire.upload(multipartFormData: { multipartFormData in
            // import data
            var countData: UInt = 0
            multiDatas.forEach({ dataExt in
                countData += 1
                let fileName = String.coreApiIsEmptyString(dataExt.name) ? "file\(countData)" : dataExt.name
                let fileNameExt = (fileName as NSString).appendingPathExtension(dataExt.fileExtension) ?? fileName
                multipartFormData.append(dataExt.data, withName: dataExt.name, fileName: fileNameExt, mimeType: dataExt.mimeType)
            })
            // import parameters
            parameters?.forEach({ (key: String, value: Any) in
                if let dataParam = JSON(value).dataValueExt {
                    multipartFormData.append(dataParam, withName: key)
                }
            })
        }, to: path.fullUrlStringWithAPIBaseURL, method: .post, headers: mergeHeaders, encodingCompletion: { encodingResult in
            switch encodingResult {
            case .success(let uploadRequest, _, _):
                uploadRequest.validate(statusCode: 200..<LHCoreRxAPIService.validateStatusCode)
                    .responseJSON { dataResponse in
                        switch dataResponse.result {
                        case .success(let resultData):
                            completion?(JSON(resultData), nil)
                        case .failure(let error):
                            completion?(JSON(), dataResponse.errorResponseWithError(error))
                        }
                }
                uploadRequest.doLogCURL()
                
            case .failure(let encodingError):
                completion?(JSON(), encodingError)
            }
        })
    }
    
    // MARK: JSON response with Rx ========================================================================
    static public func rxRequestJSON(
        method apiMethod: HTTPMethod = .get,
        apiPath path: String,
        params parameters: LHCoreApiPayload? = nil,
        headers headerParams: LHCoreApiHeaders? = nil) -> Observable<JSON> {
        
        let mergeHeaders = self.mergeDefaultHeaders(headerParams)
        let encoding: ParameterEncoding = apiMethod == .get ? URLEncoding.default : JSONEncoding.default
        
        return Observable.create({ observer -> Disposable in
            let dataRequest = Alamofire.request(path.fullUrlStringWithAPIBaseURL, method: apiMethod, parameters: parameters, encoding: encoding, headers: mergeHeaders)
                .validate(statusCode: 200..<LHCoreRxAPIService.validateStatusCode)
                .responseJSON { dataResponse in
                    switch dataResponse.result {
                    case .success(let resultData):
                        observer.onNext(JSON(resultData))
                    case .failure(let error):
                        observer.onError(dataResponse.errorResponseWithError(error))
                    }
                    
                    observer.onCompleted()
            }
            
            dataRequest.doLogCURL()
            
            return Disposables.create()
        })
    }
    
    static public func rxPostMultipartDataJSON(
        apiPath path: String,
        params parameters: LHCoreApiPayload? = nil,
        headers headerParams: LHCoreApiHeaders? = nil,
        multipartDatas multiDatas: [MultipartDataExt]) -> Observable<JSON> {
        
        return self.rxPostMultipartDataRequest(apiPath: path, params: parameters, headers: headerParams, multipartDatas: multiDatas)
            .flatMap({ dataRequest -> Observable<DataResponse<Any>> in
                dataRequest.doLogCURL()
                
                return dataRequest.validate(statusCode: 200..<LHCoreRxAPIService.validateStatusCode).rx.responseJSON()
            })
            .map({ dataResponse -> JSON in
                switch dataResponse.result {
                case .success(let resultData):
                    return JSON(resultData)
                case .failure(let error):
                    throw dataResponse.errorResponseWithError(error)
                }
            })
    }
    
    // MARK: DataRequest response ========================================================================
    static public func rxPostMultipartDataRequest(
        apiPath path: String,
        params parameters: [String: Any]? = nil,
        headers headerParams: [String: String]? = nil,
        multipartDatas multiDatas: [MultipartDataExt]) -> Observable<DataRequest> {
        
        return Observable.create({ observer -> Disposable in
            Alamofire.upload(multipartFormData: { multipartFormData in
                // import data
                var countData: UInt = 0
                multiDatas.forEach({ dataExt in
                    countData += 1
                    let fileName = String.coreApiIsEmptyString(dataExt.name) ? "file\(countData)" : dataExt.name
                    let fileNameExt = (fileName as NSString).appendingPathExtension(dataExt.fileExtension) ?? fileName
                    multipartFormData.append(dataExt.data, withName: dataExt.name, fileName: fileNameExt, mimeType: dataExt.mimeType)
                    print(fileNameExt)
                })
                // import parameters
                parameters?.forEach({ (key: String, value: Any) in
                    if let dataParam = JSON(value).dataValueExt {
                        multipartFormData.append(dataParam, withName: key)
                    }
                })
            }, to: path.fullUrlStringWithAPIBaseURL, headers: headerParams, encodingCompletion: { encodingResult in
                switch encodingResult {
                case .success(let request, _, _):
                    request.validate(statusCode: 200..<LHCoreRxAPIService.validateStatusCode)
                        .response(completionHandler: { defaultDataResponse in
                            if let error = defaultDataResponse.error {
                                observer.onError(defaultDataResponse.errorResponseWithError(error))
                            } else {
                                observer.onNext(request)
                            }
                            
                            observer.onCompleted()
                        })
                    
                    request.doLogCURL()
                    
                case .failure(let error):
                    observer.onError(error)
                }
            })
            return Disposables.create()
        })
    }
}

// MARK: Private Request Funcs ==========================================================
extension LHCoreRxAPIService {
    internal static func mergeDefaultHeaders(_ to: [String: String]?) -> [String: String]? {
        let defHeaders = self.defaultHeaders
        var headers = defHeaders ?? to
        if defHeaders != nil, to != nil {
            to?.forEach({ (key, value) in
                headers?[key] = value
            })
        }
        return headers
    }
}

extension String {
    internal var fullUrlWithAPIBaseURL: URL? {
        guard !self.lowercased().hasPrefix("http://"), !self.lowercased().hasPrefix("https://") else {
            return URL(string: self)
        }
        return URL(string: LHCoreRxAPIService.apiBaseURLString)?.appendingPathComponent(self)
    }
    
    internal var fullUrlStringWithAPIBaseURL: String {
        guard !self.lowercased().hasPrefix("http://"), !self.lowercased().hasPrefix("https://") else {
            return self
        }
        
        if let url = URL(string: LHCoreRxAPIService.apiBaseURLString)?.appendingPathComponent(self) {
            return url.absoluteString
        } else {
            return LHCoreRxAPIService.apiBaseURLString.coreApiDeleteSuffixPath + "/" + self.coreApiDeletePrefixPath
        }
    }
    
    private var coreApiDeletePrefixPath: String {
        var result = self
        while result.hasPrefix("/") {
            result.removeFirst()
        }
        return result
    }
    
    private var coreApiDeleteSuffixPath: String {
        var result = self
        while result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }
    
    internal static func coreApiIsEmptyString(_ str: String?) -> Bool {
        guard let str = str else { return true }
        return str.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == ""
    }
}

public extension JSON {
    var dataValueExt: Data? {
        do {
            let dataParser = try self.rawData()
            return dataParser
        } catch {
            return self.stringValue.data(using: String.Encoding.utf8)
        }
    }
    
    var stringTrimmed: String? { return self.string?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
    var stringValueTrimmed: String { return self.stringValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
    
    func mergedValues(with other: JSON) -> JSON {
        var merged = self
        do {
            merged = try self.merged(with: other)
        } catch { }
        return merged
    }
    
    mutating func removeItem(_ atIndex: Int) {
        guard self.type == .array else {
            return
        }
        guard self.count > atIndex, atIndex >= 0  else {
            return
        }
        var values = self.arrayValue
        values.remove(at: atIndex)
        self = JSON(values)
    }
    
    mutating func mergeArray(_ json: JSON) {
        guard self.type == .array else {
            self = self.mergedValues(with: json)
            return
        }
        
        do {
            try self.merge(with: json)
        } catch {
            var values = self.arrayValue
            json.array?.forEach({ (item) in
                values.append(item)
            })
            self = JSON(values)
        }
    }
}

public struct MultipartDataExt {
    public var data: Data
    public var name: String
    public var fileExtension: String
    public var mimeType: String = "image/jpeg"
    
    public init(data dataE: Data, name nameE: String, fileExtension fileExtensionE: String = "jpeg", mimeType mimeTypeE: String = "image/jpeg") {
        self.data = dataE
        self.name = nameE
        self.fileExtension = fileExtensionE
        self.mimeType = mimeTypeE
    }
}

public extension UIImageView {
    func alamofireSetImagePlaceHolder(_ placeholderImage: UIImage, urlString: String?) {
        self.image = placeholderImage
        if let stringUrl = urlString?.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed), let url = URL(string: stringUrl) {
            self.af_setImage(withURL: url, placeholderImage: placeholderImage)
        }
    }
    
    func alamofireSetImage(_ urlString: String?, default imgDefault: UIImage? = nil, headers: [String: String]? = nil, completion: ((DataResponse<UIImage>) -> Void)? = nil) {
        self.image = nil
        if let imageUrlStr = urlString?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), !imageUrlStr.isEmpty {
            let stringUrl = imageUrlStr.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? imageUrlStr
            if let url = URL(string: stringUrl) {
                var urlRequest = URLRequest(url: url)
                headers?.forEach({ (headerItem) in
                    urlRequest.setValue(headerItem.value, forHTTPHeaderField: headerItem.key)
                })
                self.af_setImage(withURLRequest: urlRequest, completion: completion)
            } else {
                self.image = imgDefault
                let response = DataResponse<UIImage>(request: nil, response: nil, data: nil, result: .failure(AFIError.requestCancelled))
                completion?(response)
            }
        } else {
            self.image = imgDefault
            let response = DataResponse<UIImage>(request: nil, response: nil, data: nil, result: .failure(AFIError.requestCancelled))
            completion?(response)
        }
    }
}

public extension NSError {
    var error: Error { return self as Error }
    
    var isUnauthorizedError: Bool { return self.code == LHCoreErrorCodes.unAuthorized }
    var isForbidden: Bool { return self.code == 403 }
    var isNotFound: Bool { return  self.code == 404 }
    var isForbiddenOrNotFound: Bool { return self.isForbidden || self.isNotFound }
}

public extension Error {
    var nsError: NSError { return self as NSError }
    
    var domain: String { return nsError.domain }
    var code: Int { return nsError.code }
    var userInfo: [String: Any] { return nsError.userInfo }
    
    var isUnauthorizedError: Bool { return self.code == LHCoreErrorCodes.unAuthorized }
    var isForbidden: Bool { return self.code == 403 }
    var isNotFound: Bool { return  self.code == 404 }
    var isForbiddenOrNotFound: Bool { return self.isForbidden || self.isNotFound }
}

// MARK: Request Extension for cURLDebugLog ============================================================
public extension Request {
    func doLogCURL() {
        guard LHCoreRxAPIService.enableCURLDebugLog else { return }
        
        print(self.cURLDebugLog())
    }
    
    func cURLDebugLog() -> String {
        var components = ["$ curl -v"]
        
        guard let request = self.request, let url = request.url else {
            return "$ curl command could not be created"
        }
        
        if let httpMethod = request.httpMethod, httpMethod != "GET" {
            components.append("-X \(httpMethod)")
        }
        
        if let credentialStorage = self.session.configuration.urlCredentialStorage, let host = url.host {
            let protectionSpace = URLProtectionSpace(
                host: host,
                port: url.port ?? 0,
                protocol: url.scheme,
                realm: host,
                authenticationMethod: NSURLAuthenticationMethodHTTPBasic
            )
            
            if let credentials = credentialStorage.credentials(for: protectionSpace)?.values {
                for credential in credentials {
                    guard let user = credential.user, let password = credential.password else { continue }
                    components.append("-u \(user):\(password)")
                }
            } else {
                let credentialSelector = NSSelectorFromString("credential")
                if delegate.responds(to: credentialSelector) {
                    if let credential = delegate.perform(credentialSelector).takeUnretainedValue() as? URLCredential, let user = credential.user, let password = credential.password {
                        components.append("-u \(user):\(password)")
                    }
                }
            }
        }
        
        if session.configuration.httpShouldSetCookies {
            if
                let cookieStorage = session.configuration.httpCookieStorage,
                let cookies = cookieStorage.cookies(for: url), !cookies.isEmpty
            {
                let string = cookies.reduce("") { $0 + "\($1.name)=\($1.value);" }
                
                #if swift(>=3.2)
                components.append("-b \"\(string[..<string.index(before: string.endIndex)])\"")
                #else
                components.append("-b \"\(string.substring(to: string.characters.index(before: string.endIndex)))\"")
                #endif
            }
        }
        
        var headers: [AnyHashable: Any] = [:]
        
        if let additionalHeaders = session.configuration.httpAdditionalHeaders {
            for (field, value) in additionalHeaders where field != AnyHashable("Cookie") {
                headers[field] = value
            }
        }
        
        if let headerFields = request.allHTTPHeaderFields {
            for (field, value) in headerFields where field != "Cookie" {
                headers[field] = value
            }
        }
        
        for (field, value) in headers {
            let escapedValue = String(describing: value).replacingOccurrences(of: "\"", with: "\\\"")
            components.append("-H \"\(field): \(escapedValue)\"")
        }
        
        if let httpBodyData = request.httpBody, let httpBody = String(data: httpBodyData, encoding: .utf8) {
            var escapedBody = httpBody.replacingOccurrences(of: "\\\"", with: "\\\\\"")
            escapedBody = escapedBody.replacingOccurrences(of: "\"", with: "\\\"")
            if LHCoreRxAPIService.limitedCURLDebugLogLength > 0, (escapedBody as NSString).length > LHCoreRxAPIService.limitedCURLDebugLogLength {
                escapedBody = (escapedBody as NSString).substring(to: LHCoreRxAPIService.limitedCURLDebugLogLength)
            }
            components.append("-d \"\(escapedBody)\"")
        }
        
        components.append("\"\(url.absoluteString)\"")
        
        return components.joined(separator: " \\\n\t")
    }
}

public extension HTTPURLResponse {
    var statusCodeLocalizedString: String {
        return HTTPURLResponse.localizedString(forStatusCode: self.statusCode)
    }
}

// MARK: Rx Extension for DataRequest ============================================================
public let rxAlamofireUnknownError = NSError(domain: "RxAlamofireDomain", code: -1, userInfo: [:])

public extension ObservableType where Element == DataRequest {
    func responseJSON() -> Observable<DataResponse<Any>> {
        return flatMap { $0.rx.responseJSON() }
    }
    
    func json(options: JSONSerialization.ReadingOptions = .allowFragments) -> Observable<Any> {
        return flatMap { $0.rx.json(options: options) }
    }
    
    func responseString(encoding: String.Encoding? = nil) -> Observable<(HTTPURLResponse, String)> {
        return flatMap { $0.rx.responseString(encoding: encoding) }
    }
    
    func string(encoding: String.Encoding? = nil) -> Observable<String> {
        return flatMap { $0.rx.string(encoding: encoding) }
    }
    
    func responseData() -> Observable<(HTTPURLResponse, Data)> {
        return flatMap { $0.rx.responseData() }
    }
    
    func data() -> Observable<Data> {
        return flatMap { $0.rx.data() }
    }
    
    func responsePropertyList(options: PropertyListSerialization.ReadOptions = PropertyListSerialization.ReadOptions()) -> Observable<(HTTPURLResponse, Any)> {
        return flatMap { $0.rx.responsePropertyList(options: options) }
    }
    
    func propertyList(options: PropertyListSerialization.ReadOptions = PropertyListSerialization.ReadOptions()) -> Observable<Any> {
        return flatMap { $0.rx.propertyList(options: options) }
    }
}

// MARK: Request - Validation
public extension ObservableType where Element == DataRequest {
    func validate<S: Sequence>(statusCode: S) -> Observable<Element> where S.Element == Int {
        return map { $0.validate(statusCode: statusCode) }
    }
    
    func validate() -> Observable<Element> {
        return map { $0.validate() }
    }
    
    func validate<S: Sequence>(contentType acceptableContentTypes: S) -> Observable<Element> where S.Iterator.Element == String {
        return map { $0.validate(contentType: acceptableContentTypes) }
    }
    
    func validate(_ validation: @escaping DataRequest.Validation) -> Observable<Element> {
        return map { $0.validate(validation) }
    }
}

extension Request: ReactiveCompatible {
    
}

public extension Reactive where Base: DataRequest {
    
    // MARK: Defaults
    /// - returns: A validated request based on the status code
    func validateSuccessfulResponse() -> DataRequest {
        return self.base.validate(statusCode: 200 ..< LHCoreRxAPIService.validateStatusCode)
    }
    
    func responseJSON() -> Observable<DataResponse<Any>> {
        return Observable.create { observer in
            let request = self.base
            
            request.responseJSON { response in
                if let error = response.result.error {
                    observer.on(.error(response.errorResponseWithError(error)))
                } else {
                    observer.on(.next(response))
                    observer.on(.completed)
                }
            }
            
            return Disposables.create {
                request.cancel()
            }
        }
    }
    
    func responseString() -> Observable<DataResponse<String>> {
        return Observable.create { observer in
            let request = self.base
            
            request.responseString(completionHandler: { (response) in
                if let error = response.result.error {
                    observer.on(.error(response.errorResponseWithError(error)))
                } else {
                    observer.on(.next(response))
                    observer.on(.completed)
                }
            })
            
            return Disposables.create {
                request.cancel()
            }
        }
    }
    
    /**
     Returns an `Observable` of NSData for the current request.
     - parameter cancelOnDispose: Indicates if the request has to be canceled when the observer is disposed, **default:** `false`
     - returns: An instance of `Observable<NSData>`
     */
    func responseData() -> Observable<(HTTPURLResponse, Data)> {
        return responseResult(responseSerializer: DataRequest.dataResponseSerializer())
    }
    
    func data() -> Observable<Data> {
        return result(responseSerializer: DataRequest.dataResponseSerializer())
    }
    
    /**
     Returns an `Observable` of a String for the current request
     - parameter encoding: Type of the string encoding, **default:** `nil`
     - returns: An instance of `Observable<String>`
     */
    func responseString(encoding: String.Encoding? = nil) -> Observable<(HTTPURLResponse, String)> {
        return responseResult(responseSerializer: Base.stringResponseSerializer(encoding: encoding))
    }
    
    func string(encoding: String.Encoding? = nil) -> Observable<String> {
        return result(responseSerializer: Base.stringResponseSerializer(encoding: encoding))
    }
    
    /**
     Returns an `Observable` of a serialized JSON for the current request.
     - parameter options: Reading options for JSON decoding process, **default:** `.AllowFragments`
     - returns: An instance of `Observable<AnyObject>`
     */
    func responseJSON(options: JSONSerialization.ReadingOptions = .allowFragments) -> Observable<(HTTPURLResponse, Any)> {
        return responseResult(responseSerializer: Base.jsonResponseSerializer(options: options))
    }
    
    /**
     Returns an `Observable` of a serialized JSON for the current request.
     - parameter options: Reading options for JSON decoding process, **default:** `.AllowFragments`
     - returns: An instance of `Observable<AnyObject>`
     */
    func json(options: JSONSerialization.ReadingOptions = .allowFragments) -> Observable<Any> {
        return result(responseSerializer: Base.jsonResponseSerializer(options: options))
    }
    
    /**
     Returns and `Observable` of a serialized property list for the current request.
     - parameter options: Property list reading options, **default:** `NSPropertyListReadOptions()`
     - returns: An instance of `Observable<AnyData>`
     */
    func responsePropertyList(options: PropertyListSerialization.ReadOptions = PropertyListSerialization.ReadOptions()) -> Observable<(HTTPURLResponse, Any)> {
        return responseResult(responseSerializer: Base.propertyListResponseSerializer(options: options))
    }
    
    func propertyList(options: PropertyListSerialization.ReadOptions = PropertyListSerialization.ReadOptions()) -> Observable<Any> {
        return result(responseSerializer: Base.propertyListResponseSerializer(options: options))
    }
    
    /**
     Transform a request into an observable of the serialized object.
     - parameter queue: The dispatch queue to use.
     - parameter responseSerializer: The the serializer.
     - returns: The observable of `T.SerializedObject` for the created download request.
     */
    func result<T: DataResponseSerializerProtocol>(
        queue: DispatchQueue? = nil,
        responseSerializer: T)
        -> Observable<T.SerializedObject> {
            return Observable.create { observer in
                let dataRequest = self.validateSuccessfulResponse()
                    .response(queue: queue, responseSerializer: responseSerializer) { (packedResponse) -> Void in
                        switch packedResponse.result {
                        case .success(let result):
                            if packedResponse.response != nil {
                                observer.on(.next(result))
                                observer.on(.completed)
                            } else {
                                observer.on(.error(packedResponse.errorResponseWithError(packedResponse.error ?? rxAlamofireUnknownError)))
                            }
                        case .failure(let error):
                            observer.on(.error(packedResponse.errorResponseWithError(error)))
                        }
                }
                return Disposables.create {
                    dataRequest.cancel()
                }
            }
    }
    
    /**
     Transform a request into an observable of the response and serialized object.
     - parameter queue: The dispatch queue to use.
     - parameter responseSerializer: The the serializer.
     - returns: The observable of `(NSHTTPURLResponse, T.SerializedObject)` for the created download request.
     */
    func responseResult<T: DataResponseSerializerProtocol>(queue: DispatchQueue? = nil,
                                                                  responseSerializer: T)
        -> Observable<(HTTPURLResponse, T.SerializedObject)> {
            return Observable.create { observer in
                let dataRequest = self.base
                    .response(queue: queue, responseSerializer: responseSerializer) { (packedResponse) -> Void in
                        switch packedResponse.result {
                        case .success(let result):
                            if let httpResponse = packedResponse.response {
                                observer.on(.next((httpResponse, result)))
                                observer.on(.completed)
                            } else {
                                observer.on(.error(rxAlamofireUnknownError))
                            }
                        case .failure(let error):
                            observer.on(.error(error as Error))
                        }
                }
                return Disposables.create {
                    dataRequest.cancel()
                }
            }
    }
}

public extension DataResponse {
    var errorResponse: Error? {
        guard let mError = self.error as NSError? else { return nil }
        
        if let dataRes = self.data, let responseStr = String(data: dataRes, encoding: String.Encoding.utf8) {
            var userInfo = mError.userInfo
            userInfo["responseData"] = responseStr
            return NSError(domain: mError.domain, code: mError.code, userInfo: userInfo)
        } else {
            return mError
        }
    }
    
    func errorResponseWithError(_ withError: Error) -> Error {
        let mError = withError as NSError
        if let dataRes = self.data, let responseStr = String(data: dataRes, encoding: String.Encoding.utf8) {
            var userInfo = mError.userInfo
            userInfo["responseData"] = responseStr
            return NSError(domain: mError.domain, code: mError.code, userInfo: userInfo)
        } else {
            return mError
        }
    }
}

public extension DefaultDataResponse {
    var errorResponse: Error? {
        guard let mError = self.error as NSError? else { return nil }
        
        if let dataRes = self.data, let responseStr = String(data: dataRes, encoding: String.Encoding.utf8) {
            var userInfo = mError.userInfo
            userInfo["responseData"] = responseStr
            return NSError(domain: mError.domain, code: mError.code, userInfo: userInfo)
        } else {
            return mError
        }
    }
    
    func errorResponseWithError(_ withError: Error) -> Error {
        let mError = withError as NSError
        if let dataRes = self.data, let responseStr = String(data: dataRes, encoding: String.Encoding.utf8) {
            var userInfo = mError.userInfo
            userInfo["responseData"] = responseStr
            return NSError(domain: mError.domain, code: mError.code, userInfo: userInfo)
        } else {
            return mError
        }
    }
}
