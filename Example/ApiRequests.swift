//
//  ApiRequests.swift
//  Example
//
//  Created by Dat Ng on 6/7/19.
//  Copyright © 2019 datnm (laohac83x@gmail.com). All rights reserved.
//

import Foundation
import LHCoreRxRealmExts
import RxSwift
import RealmSwift
import SwiftyJSON

class ApiRequests {
    class func fetchUserInfos(_ page: Int = 1, _ per: Int = 4) -> Observable<LHCoreListModel.ResultState<UserInfo>> {
        let params: [String : Any] = [
            ApiKeys.perPage: per,
            ApiKeys.page: page
        ]
        return LHCoreRxAPIService.rxRequestJSON(apiPath: ApiPaths.users, params: params)
            .map({ json -> LHCoreListModel.ResultState<UserInfo> in
                let users: [UserInfo] = json[ApiKeys.result].enumerated().map({ (offset, item) -> UserInfo in
                    return UserInfo(json: item.1)
                })
                let total = json[ApiKeys.meta][ApiKeys.totalCount].intValue
                return LHCoreListModel.ResultState.success((totalcount: total, items: users))
            })
    }
    
    class func fetchUserModels(_ page: Int = 1, _ per: Int = 4) -> Observable<LHCoreListModel.ResultState<UserModel>> {
        let params: [String : Any] = [
            ApiKeys.perPage: per,
            ApiKeys.page: page
        ]
        return LHCoreRxAPIService.rxRequestJSON(apiPath: ApiPaths.users, params: params)
            .map({ json -> LHCoreListModel.ResultState<UserModel> in
                let users: [UserModel] = json[ApiKeys.result].enumerated().map({ (offset, item) -> UserModel in
                    return UserModel(json: item.1)
                })
                let total = json[ApiKeys.meta][ApiKeys.totalCount].intValue
                return LHCoreListModel.ResultState.success((totalcount: total, items: users))
            })
    }
    
    class func fetchUser(_ id: Int64) -> Observable<JSON> {
        return LHCoreRxAPIService.rxRequestJSON(apiPath: String(format: ApiPaths.userDetail, id))
    }
    
    class func fetchUsersHandler(_ page: Int,_ per: Int,_ callback: @escaping (LHCoreListModel.ResultState<UserInfo>) -> Void) -> Void {
        let params: [String : Any] = [
            ApiKeys.perPage: per,
            ApiKeys.page: page
        ]
        LHCoreRxAPIService.doRequestJSON(apiPath: ApiPaths.users, params: params) { (json, error) in
            guard error == nil else {
                callback(LHCoreListModel.ResultState<UserInfo>.error(error!))
                return
            }
            
            let users = json[ApiKeys.result].enumerated().map({ (offset, item) -> UserInfo in
                return UserInfo(json: item.1)
            })
            let total = json[ApiKeys.meta][ApiKeys.totalCount].intValue
            callback(LHCoreListModel.ResultState<UserInfo>.success((totalcount: total, items: users)))
        }
    }
}
