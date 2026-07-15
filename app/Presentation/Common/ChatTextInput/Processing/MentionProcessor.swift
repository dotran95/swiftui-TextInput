//
//  MentionProcessor.swift
//  app
//
//  Mention insertion, range lookup, and atomic delete expansion.
//

import Foundation

final class MentionProcessor {

    private let attributeBuilder = AttributeBuilder()

    func makeMentionAttributedString(for mention: Mention) -> NSAttributedString {
        attributeBuilder.mentionString(for: mention, trailingSpace: true)
    }

    /// Returns the full UTF-16 range of the mention token containing `location`, if any.
    func mentionRange(containing location: Int, in text: NSAttributedString) -> NSRange? {
        guard text.length > 0 else { return nil }

        let index = min(max(0, location), text.length - 1)
        var mentionRange = NSRange(location: 0, length: 0)

        let hasMention = text.attribute(.mentionId, at: index, effectiveRange: &mentionRange) != nil
        return hasMention ? mentionRange : nil
    }

    /// Expands a delete range to cover the entire mention when any part of it is removed.
    ///
    /// Telegram/Slack-style editors treat mentions as atomic tokens.
    func expandDeleteRange(_ range: NSRange, in text: NSAttributedString) -> NSRange {
        guard range.length > 0 else { return range }

        var expanded = range

        if let mentionAtStart = mentionRange(containing: range.location, in: text) {
            expanded = expanded.union(mentionAtStart)
        }

        let endIndex = max(0, NSMaxRange(range) - 1)
        if let mentionAtEnd = mentionRange(containing: endIndex, in: text) {
            expanded = expanded.union(mentionAtEnd)
        }

        return SelectionManager.clamp(expanded, to: text.length)
    }

    /// Preserves `mentionId` on pasted fragments that already carry it.
    func preserveMentions(in attributed: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let fullRange = NSRange(location: 0, length: mutable.length)

        mutable.enumerateAttribute(.mentionId, in: fullRange) { value, range, _ in
            guard let userId = value as? String else { return }
            mutable.addAttribute(.font, value: ChatTextInputStyle.mentionFont, range: range)
            mutable.addAttribute(.foregroundColor, value: ChatTextInputStyle.mentionColor, range: range)
            mutable.addAttribute(.mentionId, value: userId, range: range)
        }

        return mutable
    }
}

private extension NSRange {
    func union(_ other: NSRange) -> NSRange {
        let start = min(location, other.location)
        let end = max(NSMaxRange(self), NSMaxRange(other))
        return NSRange(location: start, length: end - start)
    }
}
