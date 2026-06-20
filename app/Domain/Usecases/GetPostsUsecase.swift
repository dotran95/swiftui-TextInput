//
//  GetPostsUsecase.swift
//  app
//
//  Created by VTIT on 16/8/24.
//

import RxSwift

protocol GetPostsUsecaseProtocol {
    func excute(limit: Int, skip: Int) -> Single<[PostModel]>
}

struct GetPostsUsecaseImpl: GetPostsUsecaseProtocol {

    // MARK: - Properties
    private let repository: any PostRepositoryProtocol

    init(repository: any PostRepositoryProtocol) {
        self.repository = repository
    }

    func excute(limit: Int, skip: Int) -> Single<[PostModel]> {
        return repository.getPosts(limit, skip: skip)
    }
}

