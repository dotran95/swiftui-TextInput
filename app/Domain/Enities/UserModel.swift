//
//  UserModel.swift
//  app
//
//  Created by dotn on 12/8/24.
//

import Foundation

struct UserModel: Codable {
    let id: Int?
    let email, firstName, lastName: String?
    let gender: String?
    let image: String?

    static func fromApi(result: GetUserRespose) -> UserModel {
        return UserModel(id: result.id,
                         email: result.email,
                         firstName: result.firstName,
                         lastName: result.lastName,
                         gender: result.gender,
                         image: result.image)
    }

    static func fromApi(result: LoginResponse) -> UserModel {
        return UserModel(id: result.id,
                         email: result.email,
                         firstName: result.firstName,
                         lastName: result.lastName,
                         gender: result.gender,
                         image: result.image)
    }

}
