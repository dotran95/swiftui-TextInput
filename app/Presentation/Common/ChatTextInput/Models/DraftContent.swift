//
//  DraftContent.swift
//  app
//

import Foundation

/// Markdown style applied to a range in draft plain text.
enum MarkdownStyle: Equatable, Sendable {
    case bold
    case italic
    case code
    case strikethrough
}

/// Markdown metadata stored in a draft before rendering.
struct MarkdownSegment: Equatable, Sendable {
    let range: NSRange
    let style: MarkdownStyle
}

/// Initial editor payload. Must be converted through `EditorEvent.initialize`
/// — never construct `ChatTextInputState` directly from a draft.
struct DraftContent: Equatable, Sendable {
    var text: String
    var mentions: [DraftMentionMetadata]
    var markdownSegments: [MarkdownSegment]

    static let empty = DraftContent(
        text: "",
        mentions: [],
        markdownSegments: []
    )
}
