//
//  LHCoreListViewDataSource.swift
//  LHCoreRxApiJWTExts iOS
//
//  Created by Dat Ng on 6/21/19.
//  Copyright © 2019 datnm (laohac83x@gmail.com). All rights reserved.
//

import Foundation
import UIKit

public let errorUserCancelSearch = NSError(domain: "UserCancelledSearch", code: -1, userInfo: nil)

public struct LHCoreListModel {
    internal enum ViewType {
        case table
        case collection
    }
    
    public enum LayoutType {
        case one_section
        case multi_section
    }
    
    public enum ResultState<T> {
        case success((totalcount: Int, items: [T]))
        case error(Error)
        
        static var successInitial: ResultState<T> { return ResultState<T>.success((totalcount: Int.max, items: [T]())) }
    }
    
    public enum RequestType {
        case refresh
        case fetch
    }
    
    public enum RequestState: Equatable {
        public static func == (lhs: RequestState, rhs: RequestState) -> Bool {
            switch (lhs, rhs) {
            case ( .none, .none): return true
            case (let .requesting(lRequestType), let .requesting(rRequestType)): return lRequestType == rRequestType
            default: return false
            }
        }
        
        case none
        case requesting(RequestType)
    }
    
    public struct PagingParam<T> {
        public var nextPage: Int64 = 0
        public var lastItem: T?
        public var pageSize: Int = LHCoreApiDefault.pageSize
        internal var lastItemId: Int64?
        
        public init(_ nextPage: Int64 = 0, lastItem: T? = nil, pageSize: Int = LHCoreApiDefault.pageSize) {
            self.nextPage = nextPage
            self.lastItem = lastItem
            self.pageSize = pageSize
        }
    }
    
    public enum PagingType {
        case byPageNumber
        case byLastItem
    }
}

internal protocol LHCoreListViewDataSourceProtocol: class {
    func numberOfSections() -> Int
    func numberOfRowsInSection(_ section: Int) -> Int
    func itemForCell(at: IndexPath) -> Any?
}

public final class LHCoreListViewDataSource<T>: NSObject, UITableViewDataSource, UICollectionViewDataSource {
    typealias TableCellBuilder = (_ item: T, _ tableView: UITableView, _ at: IndexPath) -> UITableViewCell?
    typealias CollectionCellBuilder = (_ item: T, _ collectionView: UICollectionView, _ at: IndexPath) -> UICollectionViewCell?
    
    internal var tblCellBuilder: TableCellBuilder?
    internal var colCellBuilder: CollectionCellBuilder?
    internal var delegate: LHCoreListViewDataSourceProtocol?
    
    // MARK: For TableView =====================================================================
    public func numberOfSections(in tableView: UITableView) -> Int {
        return self.delegate?.numberOfSections() ?? 0
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.delegate?.numberOfRowsInSection(section) ?? 0
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let item = self.delegate?.itemForCell(at: indexPath) as? T else {
            return UITableViewCell()
        }
        return tblCellBuilder?(item, tableView, indexPath) ?? UITableViewCell()
    }
    
    // MARK: For CollectionView =====================================================================
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.delegate?.numberOfSections() ?? 0
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.delegate?.numberOfRowsInSection(section) ?? 0
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let item = self.delegate?.itemForCell(at: indexPath) as? T else {
            return UICollectionViewCell()
        }
        
        return colCellBuilder?(item, collectionView, indexPath)  ?? UICollectionViewCell()
    }
}
