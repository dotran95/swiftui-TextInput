//
//  GetUserResponse.swift
//  app
//
//  Created by dotn on 12/8/24.
//

import Foundation

// MARK: - GetUserRespose
struct GetUserRespose: Codable {
    let id: Int?
    let username, email, firstName, lastName: String?
    let gender: String?
    let image: String?
}
