//
//  GetUserUsecase.swift
//  app
//
//  Created by dotn on 12/8/24.
//

import RxSwift

protocol GetUserUsecaseProtocol {
    func excute() -> Single<UserModel>
}

struct GetUserUsecaseImpl: GetUserUsecaseProtocol {
    private let repository: UserRepositoryProtocol

    init(repository: UserRepositoryProtocol) {
        self.repository = repository
    }

    func excute() -> Single<UserModel> {
        return repository.getUserInfo()
    }
}
