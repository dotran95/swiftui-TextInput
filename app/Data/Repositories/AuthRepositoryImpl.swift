//
//  UserRepositoryImpl.swift
//  app
//
//  Created by dotn on 12/8/24.
//

import RxSwift
import Moya

struct AuthRepositoryImpl: AuthRepositoryProtocol {

    private let remoteDataSource: RemoteDataSourceProtocol
    
    init(remoteDataSource: RemoteDataSourceProtocol) {
        self.remoteDataSource = remoteDataSource
    }

    func login(username: String, password: String) -> Single<LoginResponse> {
        let params = LoginParams(expiresInMins: 30, username: username, password: password)
        return remoteDataSource.login(params: params)
    }
}
