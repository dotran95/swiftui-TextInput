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

    private lazy var commentsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Comments Demo", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var chatButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Chat Multi-Cell Demo", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func makeUI() {
        super.makeUI()
        let firstName = AuthManager.shared.userInfo?.firstName ?? ""

        "user_name".localized
            .map({ String(format: $0, firstName) })
            .drive(usernameLbl.rx.text)
            .disposed(by: disposebag)

        view.addSubview(commentsButton)
        view.addSubview(chatButton)
        NSLayoutConstraint.activate([
            chatButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            chatButton.bottomAnchor.constraint(equalTo: logoutButton.topAnchor, constant: -16),

            commentsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            commentsButton.bottomAnchor.constraint(equalTo: chatButton.topAnchor, constant: -12)
        ])

        logoutButton.rx.tap.subscribe { _ in
            Application.shared.onLogout()
        }.disposed(by: disposebag)

        commentsButton.rx.tap.subscribe { [weak self] _ in
            guard let self else { return }
            Application.shared.navigator.show(segue: .comments, sender: self, transition: .push)
        }.disposed(by: disposebag)

        chatButton.rx.tap.subscribe { [weak self] _ in
            guard let self else { return }
            Application.shared.navigator.show(segue: .chat, sender: self, transition: .push)
        }.disposed(by: disposebag)
    }

}
