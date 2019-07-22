//
//  MainViewController.swift
//  LHCoreExtensions
//
//  Created by Dat Ng on 04/19/2019.
//  Copyright (c) 2019 laohac83x@gmail.com. All rights reserved.
//

import UIKit
import LHCoreRxApiJWTExts
import Alamofire
import SwiftyJSON
import RxCocoa
import RxSwift

class MainViewController: UIViewController {
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        LHCoreRxAPIService.enableCURLDebugLog = true
        LHCoreRxAPIService.apiBaseURLString = "http://171.244.139.16"
        LHCoreRxAPIService.defaultHeaders = ["Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiJhYzQ4OTY0Zi1jYzU5LTQ0Y2QtODc4Yi01MzYzMmZlNWY1MzgiLCJ0eXAiOiJBZG1pbmlzdHJhdG9yLERyaXZlcixDdXN0b21lcixQYXJ0bmVyIiwiZXhwIjoxNTk1NDA0Mjk4LCJuYW1laWQiOiIxIiwic2lkIjoiIiwiYWN0b3J0Ijoie1wiVXNlcklkXCI6MSxcIkVtYWlsXCI6XCJ2aWV0ZHVuZ3ZuODhAZ21haWwuY29tXCIsXCJVc2VyTmFtZVwiOlwiTmd1eeG7hW4gVmnhu4d0IETFqW5nXCIsXCJVc2VyVHlwZVwiOltcIkFkbWluaXN0cmF0b3JcIixcIkRyaXZlclwiLFwiQ3VzdG9tZXJcIixcIlBhcnRuZXJcIl0sXCJFeHBpcmVUaW1lXCI6XCIyMDIwLTA3LTIyVDA3OjUxOjM4LjM5OTk5MzFaXCIsXCJWZWhpY2xlSWRcIjpudWxsLFwiUGFydG5lcklkXCI6MH0iLCJpc3MiOiJodHRwOi8vMTcxLjI0NC4xMzkuMTY6NTAwNSIsImF1ZCI6Imh0dHA6Ly8xNzEuMjQ0LjEzOS4xNjo1MDA1In0.so7eO5FtgV9fv6nI6hghgYHYF615QfDd2mwuBX2iaMM",
        "Content-Type": "application/json"]
        LHCoreRxAPIService.secretKeyJWT = "adcih@okrjeoj2xw=s*g)h$k%+-jjd(2bu!d(5r%-7if4)1ffqjhqcrop"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let params = [
            "StartTourId": 0,
            "Limit": 5
        ]
        LHCoreRxAPIService.rxRequestJWTEncoding(apiPath: "api/Trade/GetTradeTours", params: params)
            .observeOn(LHCoreRxAPIService.mainScheduler)
            .subscribe(onNext: { (json) in
                print(json.json)
            }, onError: { (error) in
                print(error)
            })
            .disposed(by: disposeBag)
    }
}

