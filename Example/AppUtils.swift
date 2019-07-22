//
//  AppUtils.swift
//  Example
//
//  Created by Dat Ng on 6/7/19.
//  Copyright © 2019 datnm (laohac83x@gmail.com). All rights reserved.
//

import Foundation
import LHCoreRxRealmExts

class AppUtils {
    static func doSettingApps() {
        LHCoreRxAPIService.enableCURLDebugLog = true
        LHCoreRxAPIService.apiBaseURLString = ApiHost
        LHCoreRxAPIService.defaultHeaders = ["Authorization": "Bearer nWmO_R3tsm80fbFGfcVk-lCLy-qsRpZGGYQK"]
        LHCoreApiDefault.pageSize = 4
        LHCoreApiDefault.startPage = 1
        LHCoreRealmConfig.setDefaultConfigurationMigration()
        
    }
}
