//
//  IMECompositionHandler.swift
//  app
//
//  Detects when UITextView must own text mutation for IME keyboards
//  (Vietnamese Telex/VNI, Chinese, Japanese, Korean).
//

import UIKit

enum IMECompositionHandler {

    /// Languages that rely on `markedTextRange` composition and break when
    /// `shouldChangeTextIn` returns `false`.
    private static let imeLanguagePrefixes = ["vi", "zh", "ja", "ko"]

    /// `true` when the system keyboard should apply edits directly.
    ///
    /// Returning `false` from `shouldChangeTextIn` prevents marked-text composition,
    /// which blocks Vietnamese input (e.g. Telex "uw" → "ư").
    static func shouldDelegateToSystemIME(
        _ textView: UITextView,
        isComposing: Bool
    ) -> Bool {
        if textView.markedTextRange != nil { return true }
        if isComposing { return true }

        guard let language = textView.textInputMode?.primaryLanguage else {
            return false
        }

        return imeLanguagePrefixes.contains { language.hasPrefix($0) }
    }

    static func isActivelyComposing(_ textView: UITextView) -> Bool {
        textView.markedTextRange != nil
    }
}
