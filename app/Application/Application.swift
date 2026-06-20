//
//  Application.swift
//  app
//
//  Created by dotn on 12/8/24.
//

import UIKit

class Application {
    static let shared = Application()

    // MARK: - Properties
    private let authManager: AuthManager
    private(set) var appContainer: DIContainer
    private(set) var navigator: Navigator

    private init() {
        appContainer = DIContainer()
        authManager = AuthManager.shared
        navigator = Navigator()
    }

    func presentInitialScreen() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let sceneDelegate = windowScene.delegate as? SceneDelegate,
              let window = sceneDelegate.window else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            let isAuthenticated = self.authManager.isAuthenticated
            if isAuthenticated {
                self.navigator.show(segue: .home, sender: nil, transition: .root(in: window))
            } else {
                self.navigator.show(segue: .login, sender: nil, transition: .root(in: window))
            }
        }
    }

    func loggedIn(token: String, user: UserModel) {
        authManager.onLoggedIn(token: token, userInfo: user)
        presentInitialScreen()
    }

    func onLogout() {
        authManager.onLogOut()
        presentInitialScreen()
    }
}
