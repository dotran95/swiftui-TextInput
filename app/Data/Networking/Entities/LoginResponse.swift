//
//  LoginResponse.swift
//  app
//
//  Created by dotn on 12/8/24.
//

import Foundation

struct LoginParams: Encodable {
    let expiresInMins: Int?
    let username, password: String
}

struct LoginResponse: Codable {
    let id: Int?
    let username, email, firstName, lastName: String?
    let gender: String?
    let image: String?
    let token, refreshToken: String?
}
