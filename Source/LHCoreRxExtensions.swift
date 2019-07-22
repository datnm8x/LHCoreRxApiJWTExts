//
//  LHCoreRxApiJWTExts.swift
//  LHCoreRxApiJWTExts iOS
//
//  Created by Dat Ng on 6/12/19.
//  Copyright © 2019 datnm (laohac83x@gmail.com). All rights reserved.
//

import Foundation
import UIKit
import RxCocoa
import RxSwift

extension Reactive where Base: UIScrollView {
    /// Reactive wrapper for `scrollViewDidScrollToBottom` action
    public var didScrollToBottom: ControlEvent<Bool> {
        let source = contentOffset.map { offset -> Bool in
            let scrollView = self.base as UIScrollView
            let visibleHeight = scrollView.frame.height - scrollView.contentInset.top - scrollView.contentInset.bottom
            let offsetY = offset.y + scrollView.contentInset.top
            let threshold = max(0.0, scrollView.contentSize.height - visibleHeight)
            
            return offsetY > threshold ? true : false
        }
        
        return ControlEvent(events: source)
    }
}
