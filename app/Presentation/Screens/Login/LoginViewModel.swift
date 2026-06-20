//
//  SplashViewModel.swift
//  app
//
//  Created by dotn on 9/8/24.
//

import RxSwift
import RxCocoa

class LoginViewModel: ViewModel, ViewModelType {

    // MARK: - Properties
    private let loginUsecase: LoginUsecaseProtocol

    struct Input {
        let username: Driver<String>
        let password: Driver<String>
        let trigger: Driver<Void>
    }

    struct Output {
        let isEnableLogin: Driver<Bool>
    }

    // MARK: - Init
    init(loginUsecase: LoginUsecaseProtocol) {
        self.loginUsecase = loginUsecase
    }

    func transform(input: Input) -> Output {
        let isValidateUsername = input.username.map { $0.count > 5 && $0.count < 20 }
        let isValidatePassword = input.password.map { $0.count > 5 && $0.count <= 10 }

        let isEnableLoginButton = Driver.combineLatest(isValidatePassword, isValidateUsername)
            .map({ $0 && $1 })

        input.trigger
            .withLatestFrom(isEnableLoginButton)
            .withLatestFrom(Driver.combineLatest(input.username, input.password))
            .asObservable()
            .flatMapLatest { (username, password) in
                return self.loginUsecase
                    .excute(username: username, password: password)
                    .trackError(to: self.errorSubject)
                    .trackActivity(self.loading)
                    .catch { _ in Observable.empty() }
            }
            .subscribe(onNext: { result in
                guard let token = result.token else { return }
                let user = UserModel(id: result.id,
                                                    email: result.email,
                                                    firstName: result.firstName,
                                                    lastName: result.lastName,
                                                    gender: result.gender,
                                                    image: result.image)
                Application.shared.loggedIn(token: token, user: user)
            }).disposed(by: disposeBag)

        return Output(isEnableLogin: isEnableLoginButton)
    }
}
