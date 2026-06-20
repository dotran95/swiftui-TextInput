//
//  ChatTextView.swift
//  app
//
//  UITextView subclass that routes paste through the editor pipeline.
//

import UIKit

final class ChatTextView: UITextView {

    /// Called instead of the default paste implementation.
    /// Return value is ignored; the coordinator always handles paste via `EditorProcessor`.
    var onPaste: ((NSAttributedString) -> Void)?

    override func paste(_ sender: Any?) {
        guard let onPaste else {
            super.paste(sender)
            return
        }

        let pasteboard = UIPasteboard.general
        if let attributed = pasteboard.attributedString, attributed.length > 0 {
            onPaste(attributed)
            return
        }

        if let string = pasteboard.string {
            onPaste(NSAttributedString(string: string))
            return
        }

        super.paste(sender)
    }
}
