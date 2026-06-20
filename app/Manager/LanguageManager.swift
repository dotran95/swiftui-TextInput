//
//  ThemeManager.swift
//  app
//
//  Created by dotn on 13/8/24.
//

import RxRelay
import RxCocoa

enum Languages: String {
    case en, vi
}

class LanguageManager {
    fileprivate let appLanguage: BehaviorRelay<Languages>
    private let key = "app_language"
    private let userDefaults = UserDefaults.standard

    static let shared = LanguageManager()

    private init() {
        let lang = userDefaults.string(forKey: key) ?? "vi"
        appLanguage = BehaviorRelay<Languages>(value: Languages(rawValue: lang) ?? .vi)
    }
    
    func changeLanguage(lang: Languages) {
        appLanguage.accept(lang)
        userDefaults.set(lang.rawValue, forKey: key)
    }

}

extension String {
    var localized: Driver<String> {
        return LanguageManager.shared
            .appLanguage.map { lang in
                return localized(lang.rawValue)
            }.asDriver(onErrorJustReturn: self)
    }
}
