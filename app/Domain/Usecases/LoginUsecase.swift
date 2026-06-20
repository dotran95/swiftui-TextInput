//
//  LoginUsecase.swift
//  app
//
//  Created by dotn on 12/8/24.
//

import RxSwift

protocol LoginUsecaseProtocol {
    func excute(username: String, password: String) -> Single<LoginResponse>
}

struct LoginUsecaseImpl: LoginUsecaseProtocol {

    // MARK: - Properties
    private let repository: any AuthRepositoryProtocol

    init(repository: any AuthRepositoryProtocol) {
        self.repository = repository
    }

    func excute(username: String, password: String) -> Single<LoginResponse> {
        return repository.login(username: username, password: password)
    }
}
