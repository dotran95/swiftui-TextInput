//
//  ChatTextInputState.swift
//  app
//

import Foundation

/// Render-only state for `ChatTextInputView`.
///
/// Contains only what UITextView needs to paint and position the cursor.
/// Mentions, markdown tokens, and parser output live inside `EditorProcessor`.
struct ChatTextInputState: Equatable, Sendable {
    var attributedText: NSAttributedString
    /// Source of truth for cursor / selection. `length == 0` means caret.
    var selectionRange: NSRange

    static func == (lhs: ChatTextInputState, rhs: ChatTextInputState) -> Bool {
        lhs.attributedText.isEqual(to: rhs.attributedText)
            && lhs.selectionRange.location == rhs.selectionRange.location
            && lhs.selectionRange.length == rhs.selectionRange.length
    }
}
