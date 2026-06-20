//
//  UserRepositoryImpl.swift
//  app
//
//  Created by dotn on 12/8/24.
//

import RxSwift

struct UserRepositoryImpl: UserRepositoryProtocol {

    // MARK: - Properties
    private let remoteDataSource: RemoteDataSourceProtocol

    init(remoteDataSource: RemoteDataSourceProtocol) {
        self.remoteDataSource = remoteDataSource
    }

    // MARK: - Funcs
    func getUserInfo() -> Single<UserModel> {
        return remoteDataSource.getUserInfo().map({ UserModel.fromApi(result: $0) })
    }
}
