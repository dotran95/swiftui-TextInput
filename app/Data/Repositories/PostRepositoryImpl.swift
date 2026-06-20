//
//  PostRepositoryImpl.swift
//  app
//
//  Created by VTIT on 16/8/24.
//

import RxSwift
import Moya

struct PostRepositoryImpl: PostRepositoryProtocol {

    private let remoteDataSource: RemoteDataSourceProtocol

    init(remoteDataSource: RemoteDataSourceProtocol) {
        self.remoteDataSource = remoteDataSource
    }

    func getPosts(_ limit: Int, skip: Int) -> RxSwift.Single<[PostModel]> {
        return remoteDataSource.getPosts(limit: limit, skip: skip).map { response in
            return response.posts?.map({ obj in
                return PostModel.fromApi(obj)
            }) ?? []
        }
    }

}
