//
//  PostRepositoryProtocol.swift
//  app
//
//  Created by VTIT on 16/8/24.
//

import RxSwift

protocol PostRepositoryProtocol {
    func getPosts(_ limit: Int, skip: Int) -> Single<[PostModel]>
}
