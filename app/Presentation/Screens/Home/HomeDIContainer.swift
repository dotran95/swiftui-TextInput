//
//  HomeDIContainer.swift
//  app
//
//  Created by dotn on 15/8/24.
//

import UIKit

class HomeDIContainer {

    static func makeViewController() -> HomeVc {
        let storyboard = UIStoryboard(name: "Home", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "HomeVc") as? HomeVc else {
            fatalError("LoginDIContainer not found")
        }

        let viewModel = HomeViewModel()
        vc.viewModel = viewModel
        return vc
    }

}
