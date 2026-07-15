//
//  ChatTextInputAttributes.swift
//  app
//
//  Custom NSAttributedString keys used by the chat text editor.
//

import UIKit

extension NSAttributedString.Key {
    /// Identifies a mention token. Value is `String` (userId).
    static let mentionId = NSAttributedString.Key("com.app.chatTextInput.mentionId")
}

/// Styling constants shared across builders and processors.
enum ChatTextInputStyle {
    static let bodyFont = UIFont.systemFont(ofSize: 16)
    static let bodyColor = UIColor.label
    static let mentionColor = UIColor.systemBlue
    static let mentionFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
    static let codeFont = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
    static let codeBackgroundColor = UIColor.secondarySystemBackground
}
