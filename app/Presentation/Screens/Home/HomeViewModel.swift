//
//  HomeViewModel.swift
//  app
//
//  Created by dotn on 12/8/24.
//

import RxSwift
import RxCocoa

class HomeViewModel: ViewModel, ViewModelType {

    // MARK: - Properties

    struct Input { }

    struct Output { }

    // MARK: - Init

    func transform(input: Input) -> Output {
        return Output()
    }
}
