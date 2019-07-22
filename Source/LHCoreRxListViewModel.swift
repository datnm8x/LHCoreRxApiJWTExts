//
//  LHCoreRxListViewModel.swift
//  LHCoreRxListViewModel iOS
//
//  Created by Dat Ng on 6/13/19.
//  Copyright © 2019 datnm (laohac83x@gmail.com). All rights reserved.
//

import Foundation
import UIKit
import RxCocoa
import RxSwift

open class LHCoreRxListViewModel<T> {
    public typealias TableCellBuilder = (_ item: T, _ tblView: UITableView, _ at: IndexPath) -> UITableViewCell?
    public typealias CollectionCellBuilder = (_ item: T, _ colView: UICollectionView, _ at: IndexPath) -> UICollectionViewCell?

    public typealias RxFetchFunction = (_ page: Int,_ per: Int) -> Observable<LHCoreListModel.ResultState<T>>
    public typealias RxSearchFunction = (_ keyword: String,_ page: Int,_ per: Int) -> Observable<LHCoreListModel.ResultState<T>>

    public let fetchFunction: RxFetchFunction
    public let searchFunction: RxSearchFunction?

    public let dataSource: LHCoreListViewDataSource<T> = LHCoreListViewDataSource<T>()
    internal var listType: LHCoreListModel.ViewType = .table
    open var layoutType: LHCoreListModel.LayoutType = .one_section {
        didSet {
            if layoutType != oldValue {
                self.reloadLayout()
            }
        }
    }
    
    internal var startPage: Int = LHCoreApiDefault.startPage
    internal var nextPage: Int = LHCoreApiDefault.startPage
    internal var pageSize: Int = LHCoreApiDefault.pageSize
    public let requestState = BehaviorRelay<LHCoreListModel.RequestState>(value: .none)
    internal var result: BehaviorRelay<[T]> = BehaviorRelay<[T]>(value: [T]())
    public var items: BehaviorRelay<[T]> { return result }
    public let totalcount: BehaviorRelay<Int> = BehaviorRelay<Int>(value: Int.max)
    public let didRequestHandler = BehaviorRelay<(LHCoreListModel.RequestType, LHCoreListModel.ResultState<T>)>(value: (.refresh, LHCoreListModel.ResultState<T>.successInitial))

    public let disposeBag: DisposeBag = DisposeBag()
    internal var disposeBagFetch: DisposeBag?
    internal let userScrollAction = BehaviorRelay<Bool>(value: false)
    internal var disposeBagAutoLoadMore: DisposeBag?
    internal weak var pListView: UIScrollView?

    internal var isSearchMode: Bool = false
    internal var searchKeyword: String = ""
    open var enableAutoLoadmore: Bool = true {
        didSet {
            if enableAutoLoadmore != oldValue {
                self.subcribeForAuToLoadMore()
            }
        }
    }
    public var isRequesting: Bool { return disposeBagFetch != nil && requestState.value != .none }
    internal var hasMoreData: Bool { return totalcount.value > result.value.count }
    internal var resultCount: Int { return result.value.count }
    
    public convenience init(startPage: Int = LHCoreApiDefault.startPage, pageSize: Int = LHCoreApiDefault.pageSize,
                            fetchFunc: @escaping RxFetchFunction, searchFunc: RxSearchFunction? = nil,
                            cellBuilder: @escaping TableCellBuilder)
    {
        self.init(startPage: startPage, pageSize: pageSize, fetchFunc: fetchFunc, searchFunc: searchFunc, tableCellBuilder: cellBuilder, collectionCellBuilder: nil)
        self.listType = .table
    }

    public convenience init(startPage: Int = LHCoreApiDefault.startPage, pageSize: Int = LHCoreApiDefault.pageSize,
                            fetchFunc: @escaping RxFetchFunction, searchFunc: RxSearchFunction? = nil,
                            collectionCellBuilder: @escaping CollectionCellBuilder)
    {
        self.init(startPage: startPage, pageSize: pageSize, fetchFunc: fetchFunc, searchFunc: searchFunc, tableCellBuilder: nil, collectionCellBuilder: collectionCellBuilder)
        self.listType = .collection
    }

    internal init(startPage: Int, pageSize: Int,
                     fetchFunc: @escaping RxFetchFunction, searchFunc: RxSearchFunction? = nil,
                     tableCellBuilder: TableCellBuilder?, collectionCellBuilder: CollectionCellBuilder?)
    {
        MainScheduler.ensureExecutingOnScheduler()
        
        self.startPage = startPage
        self.pageSize = pageSize
        self.fetchFunction = fetchFunc
        self.searchFunction = searchFunc

        dataSource.tblCellBuilder = tableCellBuilder
        dataSource.colCellBuilder = collectionCellBuilder
        dataSource.delegate = self
    }

    public func bindDataSource(table: UITableView?) {
        guard let tblView = table, self.listType == .table else { return }
        
        self.pListView = tblView
        tblView.dataSource = self.dataSource
        tblView.reloadData()
        
        result.observeOn(MainScheduler.instance).subscribe(onNext: { (listItems) in
            MainScheduler.ensureExecutingOnScheduler()
            tblView.reloadData()
        }).disposed(by: disposeBag)
        
        self.subcribeForAuToLoadMore()
    }
    
    public func bindDataSource(collection: UICollectionView?) {
        guard let clView = collection, self.listType == .collection else { return }
        
        self.pListView = clView
        clView.dataSource = self.dataSource
        clView.reloadData()
        
        result.observeOn(MainScheduler.instance).subscribe(onNext: { (listItems) in
            MainScheduler.ensureExecutingOnScheduler()
            clView.reloadData()
        }).disposed(by: disposeBag)
        
        self.subcribeForAuToLoadMore()
    }
    
    internal func subcribeForAuToLoadMore() {
        self.disposeBagAutoLoadMore = nil
        guard let mListView = self.pListView, enableAutoLoadmore else { return }
        
        let pDisposeBag = DisposeBag()
        self.disposeBagAutoLoadMore = pDisposeBag
        
        mListView.rx.willBeginDragging.asObservable().subscribe(onNext: { [weak self] _ in
            self?.userScrollAction.accept(true)
        }).disposed(by: pDisposeBag)
        
        mListView.rx.didScrollToBottom.asObservable().subscribe(onNext: { [weak self] isScrollToBottom in
            guard let strongSelf = self, isScrollToBottom, strongSelf.isRequesting == false, strongSelf.userScrollAction.value, strongSelf.enableAutoLoadmore else { return }
            
            if strongSelf.hasMoreData {
                strongSelf.userScrollAction.accept(false)
                DispatchQueue.main.async {
                    strongSelf.fetchMoreData()
                }
            }
        }).disposed(by: pDisposeBag)
        
        mListView.rx.didEndDragging.asObservable().subscribe(onNext: { [weak self] decelerating in
            if !decelerating {
                self?.userScrollAction.accept(false)
            }
        }).disposed(by: pDisposeBag)
        
        mListView.rx.didEndDecelerating.asObservable().subscribe(onNext: { [weak self] _ in
            self?.userScrollAction.accept(false)
        }).disposed(by: pDisposeBag)
    }
    
    public func item(atIndex: Int?) -> T? {
        guard let mIndex = atIndex else { return nil }
        return mIndex >= result.value.count ? nil : items.value[mIndex]
    }
    
    public func item(at: IndexPath?) -> T? {
        guard let indexPath = at else { return nil }
        var indexItem = indexPath.row
        if self.listType == .table {
            indexItem = self.layoutType == .one_section ? indexPath.row : indexPath.section
        } else {
            indexItem = self.layoutType == .one_section ? indexPath.item : indexPath.section
        }
        
        return self.item(atIndex: indexItem)
    }
    
    public func deleteItem(atIndex: Int?) -> T? {
        if let object = self.item(atIndex: atIndex) {
            var mTotalcount = self.totalcount.value - 1
            if (mTotalcount < 0) { mTotalcount = 0 }
            self.totalcount.accept(mTotalcount)
            var datas = self.result.value
            datas.remove(at: atIndex ?? -1)
            self.items.accept(datas)
            return object
        } else {
            return nil
        }
    }
    
    public func refreshData() {
        disposeBagFetch = nil
        if isSearchMode {
            doSearchingData(type: .refresh)
        } else {
            isSearchMode = false
            searchKeyword = ""
            doFetchData(type: .refresh)
        }
    }
    
    public func fetchMoreData() {
        guard hasMoreData else { return }
        
        isSearchMode ? doSearchingData(type: .fetch) : doFetchData(type: .fetch)
    }
    
    public func resetSearch() {
        self.isSearchMode = false
        self.refreshData()
    }
    
    public func beginSearch(_ keyword: String) {
        self.searchKeyword = keyword //Save cache for loadmore
        self.isSearchMode = true
        self.refreshData()
    }
    
    internal func doFetchData(type: LHCoreListModel.RequestType = .fetch) {
        guard disposeBagFetch == nil else {
            self.didRequestHandler.accept((type, LHCoreListModel.ResultState<T>.error(NSError(domain: String(describing: self), code: LHCoreErrorCodes.hasRequesting, userInfo: nil))))
            return
        }
        
        let pDisposeBag = DisposeBag()
        disposeBagFetch = pDisposeBag
        let requestPage = type == .refresh ? self.startPage : self.nextPage
        self.requestState.accept(.requesting(type))
        
        fetchFunction(requestPage, pageSize)
            .subscribeOn(LHCoreRxAPIService.bkgScheduler)
            .map { [unowned self] result -> LHCoreListModel.ResultState<T> in
                switch result {
                case .success(let listResult):
                    switch type {
                    case .refresh:
                        self.result.accept(listResult.items)
                    default:
                        self.result.accept(self.result.value + listResult.items)
                    }
                    self.totalcount.accept(listResult.totalcount)
                    
                case .error(_):
                    break
                }
                
                return result
            }
            .observeOn(MainScheduler.instance)
            .subscribe(
                onNext: { [unowned self] result in
                    MainScheduler.ensureExecutingOnScheduler()
                    
                    switch result {
                    case .success(_):
                        if type == .refresh { self.nextPage = self.startPage }
                        self.nextPage += 1
                        
                    case .error(let error):
                        #if DEBUG
                        print("\(self)->FetchData->error: ", error)
                        #endif
                        break
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: { [weak self] in
                        self?.requestState.accept(.none)
                        self?.disposeBagFetch = nil
                    })
                    
                    self.didRequestHandler.accept((type, result))
                },
                onError: { [unowned self] error in
                    MainScheduler.ensureExecutingOnScheduler()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: { [weak self] in
                        self?.requestState.accept(.none)
                        self?.disposeBagFetch = nil
                    })
                    
                    self.didRequestHandler.accept((type, LHCoreListModel.ResultState<T>.error(error)))
            })
            .disposed(by: pDisposeBag)
    }
    
    internal func doSearchingData(type: LHCoreListModel.RequestType) {
        guard disposeBagFetch == nil else {
            self.didRequestHandler.accept((type, LHCoreListModel.ResultState<T>.error(NSError(domain: String(describing: self), code: LHCoreErrorCodes.hasRequesting, userInfo: nil))))
            return
        }
        
        let pDisposeBag = DisposeBag()
        disposeBagFetch = pDisposeBag
        
        let nextPage = type == .fetch ? self.nextPage : startPage
        requestState.accept(.requesting(type))
        
        self.searchFunction?(self.searchKeyword, nextPage, pageSize)
            .subscribeOn(LHCoreRxAPIService.bkgScheduler)
            .map { [unowned self] result -> LHCoreListModel.ResultState<T> in
                if !self.isSearchMode {
                    // user canceled searching already
                    throw NSError(domain: "\(self)", code: LHCoreErrorCodes.userCancel, userInfo: ["message": "User did cancelled"])
                }
                
                switch result {
                case .success(let listResult):
                    switch type {
                    case .refresh:
                        self.result.accept(listResult.items)
                    default:
                        self.result.accept(self.result.value + listResult.items)
                    }
                    self.totalcount.accept(listResult.totalcount)
                    
                default: break
                }
                
                return result
            }
            .observeOn(MainScheduler.instance)
            .subscribe(
                onNext: { [unowned self] result in
                    MainScheduler.ensureExecutingOnScheduler()
                    
                    switch result {
                    case .success(_):
                        if type == .refresh { self.nextPage = self.startPage }
                        self.nextPage += 1
                        #if DEBUG
                        print("\(self)->search->success")
                        #endif
                        
                    case .error(let error):
                        #if DEBUG
                        print("\(self)->search->error: ", error)
                        #endif
                        break
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: { [weak self] in
                        self?.requestState.accept(.none)
                        self?.disposeBagFetch = nil
                    })
                    
                    self.didRequestHandler.accept((type, result))
                },
                onError: { error in
                    MainScheduler.ensureExecutingOnScheduler()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: { [weak self] in
                        self?.requestState.accept(.none)
                        self?.disposeBagFetch = nil
                    })
                    
                    self.didRequestHandler.accept((type, LHCoreListModel.ResultState<T>.error(error)))
                    #if DEBUG
                    print("\(self)->search->error: ", error)
                    #endif
            })
            .disposed(by: pDisposeBag)
    }
}

extension LHCoreRxListViewModel {
    internal func reloadLayout() {
        doReloadListView()
    }
    
    internal func doReloadListView() {
        DispatchQueue.main.async { [weak self] in
            if let tblView = self?.pListView as? UITableView {
                tblView.reloadData()
            } else if let colView = self?.pListView as? UICollectionView {
                colView.reloadData()
            }
        }
    }
}

extension LHCoreRxListViewModel: LHCoreListViewDataSourceProtocol {
    internal func numberOfSections() -> Int {
        return self.layoutType == .one_section ? 1 : self.resultCount
    }
    
    internal func numberOfRowsInSection(_ section: Int) -> Int {
        return self.layoutType == .one_section ? self.resultCount : 1
    }
    
    internal func itemForCell(at: IndexPath) -> Any? {
        return self.item(at: at)
    }
}
