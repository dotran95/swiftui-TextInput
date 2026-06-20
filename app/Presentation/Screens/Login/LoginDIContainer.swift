//
//  LoginDIContainer.swift
//  app
//
//  Created by dotn on 15/8/24.
//

import UIKit

class LoginDIContainer {

    static func makeViewController() -> LoginVc {
        let storyboard = UIStoryboard(name: "Auth", bundle: nil)
        let container = Application.shared.appContainer
        guard let usecase = container.resolve(LoginUsecaseProtocol.self),
                let vc = storyboard.instantiateViewController(withIdentifier: "LoginVc") as? LoginVc else {
            fatalError("LoginDIContainer not found")
        }

        let viewModel = LoginViewModel(loginUsecase: usecase)
        vc.viewModel = viewModel
        return vc
    }

}
