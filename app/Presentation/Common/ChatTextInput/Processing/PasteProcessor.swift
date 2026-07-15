//
//  PasteProcessor.swift
//  app
//
//  Normalizes clipboard content: plain text, attributed text, mentions, and emoji.
//

import UIKit

final class PasteProcessor {

    private let attributeBuilder = AttributeBuilder()
    private let mentionProcessor = MentionProcessor()
    private let markdownParser = MarkdownParser()

    /// Normalizes pasted content before insertion.
    ///
    /// - Plain text → base attributes
    /// - Attributed text → preserve fonts/colors where present
    /// - Mentions → keep `mentionId`
    /// - Emoji → preserved as regular UTF-16 characters
    func normalize(_ pasted: NSAttributedString) -> NSAttributedString {
        guard pasted.length > 0 else {
            return NSAttributedString(string: "", attributes: attributeBuilder.baseAttributes())
        }

        let mutable = NSMutableAttributedString(attributedString: pasted)
        normalizeMissingAttributes(in: mutable)

        let withMentions = mentionProcessor.preserveMentions(in: mutable)
        return markdownParser.reparseInline(in: withMentions)
    }

    func normalizePlainText(_ string: String) -> NSAttributedString {
        normalize(NSAttributedString(string: string, attributes: attributeBuilder.baseAttributes()))
    }

    private func normalizeMissingAttributes(in mutable: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: mutable.length)
        let defaultAttrs = attributeBuilder.baseAttributes()

        mutable.enumerateAttributes(in: fullRange) { attributes, range, _ in
            if attributes[.font] == nil, let font = defaultAttrs[.font] {
                mutable.addAttribute(.font, value: font, range: range)
            }
            if attributes[.foregroundColor] == nil, let color = defaultAttrs[.foregroundColor] {
                mutable.addAttribute(.foregroundColor, value: color, range: range)
            }
        }
    }
}
