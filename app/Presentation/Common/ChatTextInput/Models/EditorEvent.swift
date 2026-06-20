//
//  EditorEvent.swift
//  app
//

import Foundation

/// Internal editor events. Produced by `TextInputCoordinator`, consumed by `EditorProcessor`.
enum EditorEvent {
    case initialize(DraftContent)
    case textInput(range: NSRange, replacement: NSAttributedString)
    case deleteBackward(range: NSRange)
    case selectionChanged(NSRange)
    case paste(NSAttributedString)
    case insertMention(Mention)
}
