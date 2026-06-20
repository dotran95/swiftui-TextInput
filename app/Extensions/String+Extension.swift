//
//  String+Extension.swift
//  app
//
//  Created by dotn on 13/8/24.
//

import Foundation

extension String {
    func localized(_ lanCode: String) -> String {
        guard
            let bundlePath = Bundle.main.path(forResource: lanCode, ofType: "lproj"),
            let bundle = Bundle(path: bundlePath)
        else { return "" }

        return NSLocalizedString(
            self,
            bundle: bundle,
            value: " ",
            comment: ""
        )
    }

}
