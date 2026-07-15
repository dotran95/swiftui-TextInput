//
//  Mention.swift
//  app
//

import Foundation

/// A user mention inserted into the editor.
struct Mention: Equatable, Sendable {
    let userId: String
    let displayName: String
}

/// Mention metadata stored in a draft before rendering.
struct DraftMentionMetadata: Equatable, Sendable {
    let userId: String
    let displayName: String
    /// Range in plain `DraftContent.text` covering `@displayName`.
    let range: NSRange
}
