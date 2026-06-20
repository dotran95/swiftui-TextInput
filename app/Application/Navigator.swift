//
//  Navigator.swift
//  app
//
//  Created by dotn on 15/8/24.
//

import UIKit

class Navigator {
    enum Scene {
        case splash
        case home
        case login
    }

    enum Transition {
        case root(in: UIWindow)
        case modal
        case push
        case alert
    }

    func pop(sender: UIViewController?, toRoot: Bool = false) {
        if toRoot {
            sender?.navigationController?.popToRootViewController(animated: true)
        } else {
            sender?.navigationController?.popViewController(animated: true)
        }
    }

    func dismiss(sender: UIViewController?) {
        sender?.navigationController?.dismiss(animated: true, completion: nil)
    }

    // MARK: - invoke a single segue
    func show(segue: Scene, sender: UIViewController?, transition: Transition = .push) {
        let target = get(segue: segue)
        show(target: target, sender: sender, transition: transition)
    }

    private func show(target: UIViewController, sender: UIViewController?, transition: Transition) {
        switch transition {
        case .root(let window):
            window.rootViewController = target
        case .push:
            sender?.navigationController?.pushViewController(target, animated: true)
        default:
            sender?.present(target, animated: true, completion: nil)
        }
    }

    func get(segue: Scene) -> UIViewController {
        switch segue {
        case .home:
            return HomeDIContainer.makeViewController()
        case .login:
            return LoginDIContainer.makeViewController()
        case .splash:
            return SplashDIContainer.makeViewController()
        }
    }

}
