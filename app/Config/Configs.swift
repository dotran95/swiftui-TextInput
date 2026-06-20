//
//  Configs.swift
//  app
//
//  Created by dotn on 8/8/24.
//

import Foundation

class Configs {

    static let share = Configs()

    let baseUrl: String

    let loggingEnabled: Bool
    let apiTimeOut = 60
    let bundleIdentifier: String

    private init() {
        guard let baseUrl = Bundle.main.object(forInfoDictionaryKey: "BaseURL") as? String,
              let identifier = Bundle.main.bundleIdentifier
        else { fatalError("Config not found not found") }

#if DEBUG
        loggingEnabled = true
#else
        loggingEnabled = false
#endif

        self.baseUrl = baseUrl
        self.bundleIdentifier = identifier

    }

}
