//
//  PrimitiveSequenceType+Error.swift
//  app
//
//  Created by dotn on 13/8/24.
//

import RxSwift

extension ObservableConvertibleType {
    func trackError(to source: ErrorTracker) -> Observable<Element> {
        return self.asObservable().do(onError: { source.next(err: $0) })
    }
}

class ErrorTracker {
    private let _subject = PublishSubject<Error>()

    func next(err: Error) {
        _subject.onNext(err)
    }

    func asObservable() -> Observable<Error> {
        return _subject.asObservable()
    }
}
