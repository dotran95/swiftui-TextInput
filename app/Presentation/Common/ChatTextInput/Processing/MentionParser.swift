//
//  MentionParser.swift
//  app
//
//  Applies draft mention metadata onto plain text during initialize.
//

import Foundation

final class MentionParser {

    private let attributeBuilder = AttributeBuilder()

    /// Converts plain draft text + mention metadata into an attributed string.
    ///
    /// Flow step: `DraftContent` → `MentionParser` → attributed base for markdown pass.
    func parse(draft: DraftContent) -> NSAttributedString {
        let mutable = NSMutableAttributedString(
            string: draft.text,
            attributes: attributeBuilder.baseAttributes()
        )

        let sortedMentions = draft.mentions.sorted { $0.range.location < $1.range.location }
        for metadata in sortedMentions {
            apply(metadata, to: mutable)
        }

        return mutable
    }

    private func apply(_ metadata: DraftMentionMetadata, to mutable: NSMutableAttributedString) {
        let range = SelectionManager.clamp(metadata.range, to: mutable.length)
        guard range.length > 0 else { return }

        let mention = Mention(userId: metadata.userId, displayName: metadata.displayName)
        let expected = "@\(metadata.displayName)"
        let actual = (mutable.string as NSString).substring(with: range)

        guard actual == expected else { return }

        mutable.addAttribute(.mentionId, value: mention.userId, range: range)
        mutable.addAttribute(.font, value: ChatTextInputStyle.mentionFont, range: range)
        mutable.addAttribute(.foregroundColor, value: ChatTextInputStyle.mentionColor, range: range)
    }
}
