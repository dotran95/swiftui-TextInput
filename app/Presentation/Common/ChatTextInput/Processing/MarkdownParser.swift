//
//  MarkdownParser.swift
//  app
//
//  Parses inline markdown syntax and applies draft markdown metadata.
//

import Foundation

final class MarkdownParser {

    private let attributeBuilder = AttributeBuilder()

    /// Applies explicit draft segments, then scans for inline markdown delimiters.
    func parse(attributedText: NSAttributedString, draftSegments: [MarkdownSegment]) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedText)

        let sortedSegments = draftSegments.sorted { $0.range.location < $1.range.location }
        for segment in sortedSegments {
            let range = SelectionManager.clamp(segment.range, to: mutable.length)
            guard range.length > 0 else { continue }
            attributeBuilder.apply(segment.style, to: range, in: mutable)
        }

        applyInlineSyntax(to: mutable)
        return mutable
    }

    /// Re-parses inline markdown after typing or paste without touching mention attributes.
    func reparseInline(in attributedText: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedText)
        stripInlineMarkers(from: mutable)
        applyInlineSyntax(to: mutable)
        return mutable
    }

  // MARK: - Inline syntax

    private func applyInlineSyntax(to mutable: NSMutableAttributedString) {
        applyPattern(#"\*\*(.+?)\*\*"#, style: .bold, in: mutable)
        applyPattern(#"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, style: .italic, in: mutable)
        applyPattern(#"`(.+?)`"#, style: .code, in: mutable)
        applyPattern(#"~~(.+?)~~"#, style: .strikethrough, in: mutable)
    }

    private func applyPattern(
        _ pattern: String,
        style: MarkdownStyle,
        in mutable: NSMutableAttributedString
    ) {
        let string = mutable.string
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let matches = regex.matches(
            in: string,
            range: NSRange(location: 0, length: (string as NSString).length)
        ).reversed()

        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }

            let fullRange = match.range(at: 0)
            let contentRange = match.range(at: 1)

            if rangeIntersectsMention(fullRange, in: mutable) { continue }

            let content = (string as NSString).substring(with: contentRange)
            mutable.replaceCharacters(in: fullRange, with: content)

            let styledRange = NSRange(location: fullRange.location, length: contentRange.length)
            attributeBuilder.apply(style, to: styledRange, in: mutable)
        }
    }

    /// Removes previously inserted markdown wrapper characters before a fresh parse.
    private func stripInlineMarkers(from mutable: NSMutableAttributedString) {
        // Inline markers are consumed during `applyPattern`; nothing to strip on a fresh string.
        // This hook exists for future incremental parsing extensions (hashtag, quote, etc.).
    }

    private func rangeIntersectsMention(_ range: NSRange, in mutable: NSMutableAttributedString) -> Bool {
        var intersects = false
        mutable.enumerateAttribute(.mentionId, in: range) { value, _, stop in
            if value != nil {
                intersects = true
                stop.pointee = true
            }
        }
        return intersects
    }
}
