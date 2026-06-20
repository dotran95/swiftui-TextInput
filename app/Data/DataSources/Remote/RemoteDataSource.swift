//
//  RemoteDataSource.swift
//  app
//
//  Created by dotn on 12/8/24.
//

import RxSwift

protocol RemoteDataSourceProtocol {
    func login(params: LoginParams) -> Single<LoginResponse>
    func getUserInfo() -> Single<GetUserRespose>
    func getPosts(limit: Int, skip: Int) -> Single<GetPostsResponse>
}
