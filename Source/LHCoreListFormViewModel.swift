//
//  LHCoreListFormViewModel.swift
//  LHCoreRxApiJWTExts
//
//  Created by Dat Ng on 6/3/19.
//  Copyright © 2019 datnm (laohac83x@gmail.com). All rights reserved.
//

import Foundation
import UIKit
import RxCocoa
import RxSwift

open class LHCoreFormCellModel {
    open var section: Int = 0
    open var row: Int = 0
    
    public init(section s: Int = 0, row r: Int = 0) {
        self.section = s
        self.row = r
    }
}

public final class LHCoreFormViewModel<C: LHCoreFormCellModel> {
    public var numberOfSections: Int = 1
    public var section: Int = 0
    public var cells: [C] = [C]()
    
    public init(section: Int = 0, cells: [C] = [C]()) {
        self.section = section
        self.cells = cells
    }
}

open class LHCoreListFormViewModel<C: LHCoreFormCellModel, T: LHCoreFormViewModel<C>> {
    public typealias FormCellBuilder = (_ formCell: C, _ tableView: UITableView, _ atIndexPath: IndexPath) -> UITableViewCell?
    
    internal var iDatas: BehaviorRelay<[T]> = BehaviorRelay<[T]>(value: [T]())
    public var datas: BehaviorRelay<[T]> { return iDatas }
    public let dataSource: LHCoreListFormViewDataSource<C, T> = LHCoreListFormViewDataSource<C, T>()
    
    public init(forms: [T], cellBuilder: @escaping FormCellBuilder) {
        self.iDatas.accept(forms)
        dataSource.formCellBuilder = cellBuilder
        dataSource.mListFormViewModel = self
    }
    
    public func item(atIndex: IndexPath?) -> C? {
        guard let sIndex = atIndex?.section, let rowIndex = atIndex?.row else { return nil }
        guard sIndex < iDatas.value.count else { return nil }
        let sItem = iDatas.value[sIndex]
        guard rowIndex < sItem.cells.count else { return nil }
        return sItem.cells[rowIndex]
    }
    
    public func bindDataSource(_ tableView: UITableView?) {
        tableView?.dataSource = self.dataSource
        tableView?.reloadData()
    }
}

public final class LHCoreListFormViewDataSource<C: LHCoreFormCellModel, T: LHCoreFormViewModel<C>>: NSObject, UITableViewDataSource {
    typealias FormCellBuilder = (_ formCell: C, _ tableView: UITableView, _ atIndexPath: IndexPath) -> UITableViewCell?
    
    fileprivate var formCellBuilder: FormCellBuilder?
    fileprivate var mListFormViewModel: LHCoreListFormViewModel<C, T>?
    public var listFormViewModel: LHCoreListFormViewModel<C, T>? {
        return mListFormViewModel
    }
    
    // MARK: For TableView =====================================================================
    public func numberOfSections(in tableView: UITableView) -> Int {
        guard let lViewModel = self.listFormViewModel else { return 0 }
        
        return lViewModel.iDatas.value.count
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let lViewModel = self.listFormViewModel else { return 0 }
        guard section < lViewModel.iDatas.value.count else { return 0 }
        
        return lViewModel.iDatas.value[section].cells.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cellForm = self.listFormViewModel?.item(atIndex: indexPath) else {
            return UITableViewCell()
        }
        
        return formCellBuilder?(cellForm, tableView, indexPath) ?? UITableViewCell()
    }
}
