//
//  AttributeBuilder.swift
//  app
//
//  Builds NSAttributedString fragments with consistent base, mention, and markdown styling.
//

import UIKit

final class AttributeBuilder {

  // MARK: - Base attributes

    var defaultTypingAttributes: [NSAttributedString.Key: Any] {
        [
            .font: ChatTextInputStyle.bodyFont,
            .foregroundColor: ChatTextInputStyle.bodyColor
        ]
    }

    func baseAttributes() -> [NSAttributedString.Key: Any] {
        defaultTypingAttributes
    }

    /// Attributes applied while the user is typing at `location`.
    ///
    /// Prevents new characters from inheriting `mentionId` when the caret sits
    /// right after a mention token.
    func typingAttributes(
        at location: Int,
        in attributedText: NSAttributedString
    ) -> [NSAttributedString.Key: Any] {
        guard attributedText.length > 0, location > 0 else {
            return defaultTypingAttributes
        }

        let probeIndex = min(location - 1, attributedText.length - 1)
        var attributes = attributedText.attributes(at: probeIndex, effectiveRange: nil)

        // Never inherit mention identity for newly typed characters.
        attributes.removeValue(forKey: .mentionId)

        if attributes[.font] == nil {
            attributes[.font] = ChatTextInputStyle.bodyFont
        }
        if attributes[.foregroundColor] == nil {
            attributes[.foregroundColor] = ChatTextInputStyle.bodyColor
        }

        return attributes
    }

  // MARK: - Fragments

    func plainString(_ string: String) -> NSAttributedString {
        NSAttributedString(string: string, attributes: baseAttributes())
    }

    /// Builds `@displayName ` with `mentionId` covering the visible mention text.
    func mentionString(for mention: Mention, trailingSpace: Bool = true) -> NSAttributedString {
        let visible = "@\(mention.displayName)"
        let suffix = trailingSpace ? " " : ""
        let full = visible + suffix

        let result = NSMutableAttributedString(string: full, attributes: baseAttributes())
        let mentionRange = NSRange(location: 0, length: visible.utf16.count)
        result.addAttribute(.mentionId, value: mention.userId, range: mentionRange)
        result.addAttribute(.font, value: ChatTextInputStyle.mentionFont, range: mentionRange)
        result.addAttribute(.foregroundColor, value: ChatTextInputStyle.mentionColor, range: mentionRange)
        return result
    }

    /// Strips mention identity from keyboard input so typing never creates fake mentions.
    func sanitizeTypingReplacement(_ replacement: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: replacement)
        let fullRange = NSRange(location: 0, length: mutable.length)

        mutable.removeAttribute(.mentionId, range: fullRange)
        mutable.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            if value == nil {
                mutable.addAttribute(.font, value: ChatTextInputStyle.bodyFont, range: range)
            }
        }
        mutable.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
            if value == nil {
                mutable.addAttribute(.foregroundColor, value: ChatTextInputStyle.bodyColor, range: range)
            }
        }

        return mutable
    }

  // MARK: - Markdown styling

    func apply(_ style: MarkdownStyle, to range: NSRange, in mutable: NSMutableAttributedString) {
        guard range.length > 0,
              NSMaxRange(range) <= mutable.length else { return }

        switch style {
        case .bold:
            mutable.enumerateAttribute(.font, in: range) { value, subRange, _ in
                let current = (value as? UIFont) ?? ChatTextInputStyle.bodyFont
                let traits = current.fontDescriptor.symbolicTraits.union(.traitBold)
                if let descriptor = current.fontDescriptor.withSymbolicTraits(traits) {
                    mutable.addAttribute(.font, value: UIFont(descriptor: descriptor, size: current.pointSize), range: subRange)
                }
            }
        case .italic:
            mutable.enumerateAttribute(.font, in: range) { value, subRange, _ in
                let current = (value as? UIFont) ?? ChatTextInputStyle.bodyFont
                let traits = current.fontDescriptor.symbolicTraits.union(.traitItalic)
                if let descriptor = current.fontDescriptor.withSymbolicTraits(traits) {
                    mutable.addAttribute(.font, value: UIFont(descriptor: descriptor, size: current.pointSize), range: subRange)
                }
            }
        case .code:
            mutable.addAttribute(.font, value: ChatTextInputStyle.codeFont, range: range)
            mutable.addAttribute(.backgroundColor, value: ChatTextInputStyle.codeBackgroundColor, range: range)
        case .strikethrough:
            mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
    }
}
