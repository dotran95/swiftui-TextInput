//
//  ViewModelType.swift
//  app
//
//  Created by dotn on 9/8/24.
//

import RxRelay
import RxSwift

protocol ViewModelType {
    associatedtype Input
    associatedtype Output

    func transform(input: Input) -> Output
}

class ViewModel: NSObject {

    let errorSubject = ErrorTracker()
    let loading = ActivityIndicator()
    let disposeBag = DisposeBag()

    lazy private(set) var className: String = {
      return type(of: self).description().components(separatedBy: ".").last ?? ""
    }()

    override init() {
        super.init()
        errorSubject.asObservable().subscribe(on: MainScheduler.instance).subscribe(onNext: { error in
            logger.debug(error.localizedDescription)
        }).disposed(by: disposeBag)
    }

    deinit {
        logger.verbose("DEINIT: \(self.className)")
    }

}
