//
//  LoginVc.swift
//  app
//
//  Created by dotn on 12/8/24.
//

import UIKit

class LoginVc: ViewController<LoginViewModel> {

    @IBOutlet weak var usernameTextfield: UITextField!
    @IBOutlet weak var passwordTextfield: UITextField!
    @IBOutlet weak var loginButton: UIButton!

    override func bindViewModel() {
        super.bindViewModel()
        guard let vm = viewModel else {
            return
        }

        let input = LoginViewModel.Input(username: usernameTextfield.rx.text.orEmpty.asDriver(),
                                         password: passwordTextfield.rx.text.orEmpty.asDriver(),
                                         trigger: loginButton.rx.tap.asDriver())

        let output = vm.transform(input: input)

        _ = output.isEnableLogin.asObservable().bind(to: loginButton.rx.isEnabled).disposed(by: disposebag)

        let a = DatabaseManager.shared
    }
}
