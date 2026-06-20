//
//  SplashVc.swift
//  app
//
//  Created by dotn on 9/8/24.
//

import UIKit
import RxCocoa
import RxSwift

class SplashVc: ViewController<SplashViewModel> {

    @IBOutlet weak private var userNameLbl: UILabel!

    override func bindViewModel() {
        super.bindViewModel()
        guard let vm = viewModel else { return }
        userNameLbl.text = "Loading..."

        let isAuthenticated = AuthManager.shared.isAuthenticated
        if !isAuthenticated {
            Application.shared.presentInitialScreen()
            return
        }

        let output = vm.transform(input: SplashViewModel.Input())
        output.loggedIn
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { _ in
                Application.shared.presentInitialScreen()
            }).disposed(by: disposebag)

    }
}
