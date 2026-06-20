//
//  UserRepository.swift
//  app
//
//  Created by dotn on 12/8/24.
//

import RxSwift

protocol UserRepositoryProtocol {
    func getUserInfo() -> Single<UserModel>
}
