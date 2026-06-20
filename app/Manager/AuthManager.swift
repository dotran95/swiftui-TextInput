//
//  AuthManager.swift
//  app
//
//  Created by dotn on 13/8/24.
//

import Foundation
import KeychainAccess

class AuthManager {

    static let shared = AuthManager()

    // MARK: - Properties
    var token: String? { return try? keychain.get(tokenKey) }
    var isAuthenticated: Bool { token != nil }
    private(set) var userInfo: UserModel?

    // MARK: - Private Properties
    fileprivate let tokenKey = "TokenKey"
    fileprivate let keychain = Keychain(service: Configs.share.bundleIdentifier)

    private init() {}

    func onLoggedIn(token: String, userInfo: UserModel) {
        try? keychain.set(token, key: tokenKey)
        self.userInfo = userInfo
    }

    func onUpdateUserInfo(userInfo: UserModel) {
        self.userInfo = userInfo
    }

    func onLogOut() {
        try? keychain.removeAll()
    }

}
