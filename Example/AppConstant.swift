//
//  AppConstant.swift
//  Example
//
//  Created by Dat Ng on 6/7/19.
//  Copyright © 2019 datnm (laohac83x@gmail.com). All rights reserved.
//

import Foundation
import UIKit

struct StoryboardsMgr {
    static let main = UIStoryboard(name: "Main", bundle: nil)
}

let ApiHost = "https://gorest.co.in/public-api"

struct ApiPaths {
    static let users = "users"
    static let userDetail = "users/%d"
    
}

struct ApiKeys {
    static let page = "page"
    
    static let result = "result"
    static let meta = "_meta"
    static let totalCount = "totalCount"
    static let pageCount = "pageCount"
    static let currentPage = "currentPage"
    static let perPage = "perPage"
    static let id = "id"
    static let first_name = "first_name"
    static let last_name = "last_name"
    static let email = "email"
    static let status = "status"
    static let gender = "gender"
    static let phone = "phone"
    static let address = "address"
    
    static let links = "_links"
    static let avatar = "avatar"
    static let href = "href"
}
