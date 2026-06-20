//
//  HomeVc.swift
//  app
//
//  Created by dotn on 12/8/24.
//

import UIKit
import RxSwift

class HomeVc: ViewController<HomeViewModel> {

    @IBOutlet weak private var usernameLbl: UILabel!
    @IBOutlet weak private var logoutButton: UIButton!

    override func makeUI() {
        super.makeUI()
        let firstName = AuthManager.shared.userInfo?.firstName ?? ""

        "user_name".localized
            .map({ String(format: $0, firstName) })
            .drive(usernameLbl.rx.text)
            .disposed(by: disposebag)

        logoutButton.rx.tap.subscribe { _ in
            Application.shared.onLogout()
        }.disposed(by: disposebag)
    }

}
