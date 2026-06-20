//
//  AuthRepository.swift
//  app
//
//  Created by dotn on 12/8/24.
//

import RxSwift

protocol AuthRepositoryProtocol {
    func login(username: String, password: String) -> Single<LoginResponse>
}
