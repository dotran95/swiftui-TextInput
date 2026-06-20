//
//  SVProcessHub+Rx.swift
//  app
//
//  Created by dotn on 13/8/24.
//

import RxSwift
import SVProgressHUD

extension Reactive where Base: SVProgressHUD {

    static var isAnimating: Binder<Bool> {
      return Binder(UIApplication.shared) {_, isVisible in
         if isVisible {
            SVProgressHUD.show()
         } else {
            SVProgressHUD.dismiss()
         }
      }
   }

}
