//
//  SplashViewModel.swift
//  app
//
//  Created by dotn on 9/8/24.
//

import RxSwift
import RxCocoa

class SplashViewModel: ViewModel, ViewModelType {

    // MARK: - Properties
    private let userUsecase: GetUserUsecaseProtocol

    struct Input { }

    struct Output {
        let loggedIn: PublishRelay<Bool>
    }

    // MARK: - Init
    init(userUsecase: GetUserUsecaseProtocol) {
        self.userUsecase = userUsecase
    }

    func transform(input: Input) -> Output {
        let loggedIn = PublishRelay<Bool>()

        userUsecase.excute().subscribe(onSuccess: { user in
            loggedIn.accept(true)
            AuthManager.shared.onUpdateUserInfo(userInfo: user)
        }, onFailure: { _ in
            loggedIn.accept(false)
            AuthManager.shared.onLogOut()
        }).disposed(by: disposeBag)

        return Output(loggedIn: loggedIn)
    }
}
