//
//  IMECompositionHandler.swift
//  app
//
//  IME composition helpers for UITextView.
//

import UIKit

enum IMECompositionHandler {

    /// CJK keyboards use `markedTextRange` for composition.
  ///
  /// Vietnamese Telex/VNI does **not** — it transforms prior characters in-place
  /// via `shouldChangeTextIn` (e.g. `a` + `s` → `á`) while `markedTextRange` stays `nil`.
  /// Vietnamese is handled by always returning `true` for insertions in the coordinator.
    static func isActivelyComposing(_ textView: UITextView) -> Bool {
        textView.markedTextRange != nil
    }
}
