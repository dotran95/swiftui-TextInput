//
//  SelectionManager.swift
//  app
//
//  Centralizes cursor / selection calculations so every action follows the same rules.
//

import Foundation

enum SelectionManager {

    /// Clamps a range so it never exceeds `textLength`.
    static func clamp(_ range: NSRange, to textLength: Int) -> NSRange {
        guard textLength > 0 else {
            return NSRange(location: 0, length: 0)
        }

        let location = min(max(0, range.location), textLength)
        let maxLength = textLength - location
        let length = min(max(0, range.length), maxLength)
        return NSRange(location: location, length: length)
    }

    /// Caret placed at the end of the attributed string.
    static func atEnd(of attributedText: NSAttributedString) -> NSRange {
        NSRange(location: attributedText.length, length: 0)
    }

    /// Caret immediately after an insertion at `replacedRange`.
    ///
    /// Example: "Hello |World" paste "ABC" at location 6 → caret at 6 + 3 = 9.
    static func afterReplacement(
        replacedRange: NSRange,
        replacementLength: Int
    ) -> NSRange {
        NSRange(location: replacedRange.location + replacementLength, length: 0)
    }

    /// Resolves the UITextView delete range.
    ///
    /// When `length == 0`, UIKit reports the caret location and expects a single
    /// backward delete. We expand that to `(location - 1, 1)`.
    static func deleteRange(from uiRange: NSRange, textLength: Int) -> NSRange? {
        if uiRange.length > 0 {
            return clamp(uiRange, to: textLength)
        }

        guard uiRange.location > 0 else { return nil }

        return NSRange(location: uiRange.location - 1, length: 1)
    }

    /// Returns `true` when two ranges represent the same caret / selection.
    static func isEqual(_ lhs: NSRange, _ rhs: NSRange) -> Bool {
        lhs.location == rhs.location && lhs.length == rhs.length
    }
}
