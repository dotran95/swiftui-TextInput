//
//  SplashDIContainer.swift
//  app
//
//  Created by dotn on 15/8/24.
//
import UIKit

class SplashDIContainer {

    static func makeViewController() -> SplashVc {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let container = Application.shared.appContainer
        guard let usecase = container.resolve(GetUserUsecaseProtocol.self),
                let vc = storyboard.instantiateViewController(withIdentifier: "SplashVc") as? SplashVc else {
            fatalError("SplashDIContainer not found")
        }

        let viewModel = SplashViewModel(userUsecase: usecase)
        vc.viewModel = viewModel
        return vc
    }

}
