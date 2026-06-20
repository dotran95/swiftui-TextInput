//
//  EditorProcessor.swift
//  app
//
//  Single entry point for all editor mutations.
//  Only this type may change `attributedText` and `selectionRange`.
//

import Foundation

final class EditorProcessor {

    private let attributeBuilder = AttributeBuilder()
    private let mentionParser = MentionParser()
    private let markdownParser = MarkdownParser()
    private let mentionProcessor = MentionProcessor()
    private let pasteProcessor = PasteProcessor()

    func process(
        currentState: ChatTextInputState?,
        event: EditorEvent
    ) -> ChatTextInputState {
        switch event {
        case .initialize(let draft):
            return initialize(from: draft)
        case .textInput(let range, let replacement):
            return handleTextInput(currentState: currentState, range: range, replacement: replacement)
        case .deleteBackward(let range):
            return handleDeleteBackward(currentState: currentState, range: range)
        case .selectionChanged(let range):
            return handleSelectionChanged(currentState: currentState, range: range)
        case .paste(let content):
            return handlePaste(currentState: currentState, content: content)
        case .insertMention(let mention):
            return handleInsertMention(currentState: currentState, mention: mention)
        }
    }

  // MARK: - Initialize

    /// DraftContent → MentionParser → MarkdownParser → AttributeBuilder → ChatTextInputState
    ///
    /// Default selection: caret at end of text.
    private func initialize(from draft: DraftContent) -> ChatTextInputState {
        let withMentions = mentionParser.parse(draft: draft)
        let withMarkdown = markdownParser.parse(
            attributedText: withMentions,
            draftSegments: draft.markdownSegments
        )

        return ChatTextInputState(
            attributedText: withMarkdown,
            selectionRange: SelectionManager.atEnd(of: withMarkdown)
        )
    }

  // MARK: - Typing

    /// User types characters at `range`. Caret moves to end of inserted text.
    ///
    /// Example: "Hello |" + "A" → "Hello A|"
    private func handleTextInput(
        currentState: ChatTextInputState?,
        range: NSRange,
        replacement: NSAttributedString
    ) -> ChatTextInputState {
        guard let currentState else {
            return initialize(from: .empty)
        }

        let textLength = currentState.attributedText.length
        let replaceRange = SelectionManager.clamp(range, to: textLength)
        let sanitized = attributeBuilder.sanitizeTypingReplacement(replacement)

        let mutable = NSMutableAttributedString(attributedString: currentState.attributedText)
        mutable.replaceCharacters(in: replaceRange, with: sanitized)

        // Markdown re-parse is limited to paste/initialize so cursor math stays stable while typing.
        let newSelection = SelectionManager.afterReplacement(
            replacedRange: replaceRange,
            replacementLength: sanitized.length
        )

        return ChatTextInputState(
            attributedText: mutable,
            selectionRange: SelectionManager.clamp(newSelection, to: mutable.length)
        )
    }

  // MARK: - Delete

    private func handleDeleteBackward(
        currentState: ChatTextInputState?,
        range: NSRange
    ) -> ChatTextInputState {
        guard let currentState else {
            return initialize(from: .empty)
        }

        let textLength = currentState.attributedText.length
        guard let deleteRange = SelectionManager.deleteRange(from: range, textLength: textLength) else {
            return currentState
        }

        let expandedRange = mentionProcessor.expandDeleteRange(
            deleteRange,
            in: currentState.attributedText
        )

        let mutable = NSMutableAttributedString(attributedString: currentState.attributedText)
        mutable.deleteCharacters(in: expandedRange)

        let newSelection = NSRange(location: expandedRange.location, length: 0)

        return ChatTextInputState(
            attributedText: mutable,
            selectionRange: SelectionManager.clamp(newSelection, to: mutable.length)
        )
    }

  // MARK: - Selection

    /// User taps to move the caret. `selectionRange` mirrors UITextView exactly.
    private func handleSelectionChanged(
        currentState: ChatTextInputState?,
        range: NSRange
    ) -> ChatTextInputState {
        guard let currentState else {
            return initialize(from: .empty)
        }

        let clamped = SelectionManager.clamp(range, to: currentState.attributedText.length)
        guard !SelectionManager.isEqual(clamped, currentState.selectionRange) else {
            return currentState
        }

        return ChatTextInputState(
            attributedText: currentState.attributedText,
            selectionRange: clamped
        )
    }

  // MARK: - Paste

    /// Inserts normalized clipboard content at the current selection.
    ///
    /// Example: "Hello |World" paste "ABC" → "Hello ABC|World"
    private func handlePaste(
        currentState: ChatTextInputState?,
        content: NSAttributedString
    ) -> ChatTextInputState {
        guard let currentState else {
            let normalized = pasteProcessor.normalize(content)
            return ChatTextInputState(
                attributedText: normalized,
                selectionRange: SelectionManager.atEnd(of: normalized)
            )
        }

        let normalized = pasteProcessor.normalize(content)
        let insertRange = SelectionManager.clamp(currentState.selectionRange, to: currentState.attributedText.length)

        let mutable = NSMutableAttributedString(attributedString: currentState.attributedText)
        mutable.replaceCharacters(in: insertRange, with: normalized)

        let newSelection = SelectionManager.afterReplacement(
            replacedRange: insertRange,
            replacementLength: normalized.length
        )

        return ChatTextInputState(
            attributedText: mutable,
            selectionRange: SelectionManager.clamp(newSelection, to: mutable.length)
        )
    }

  // MARK: - Mention

    /// Inserts `@displayName ` at the caret. Cursor ends after the trailing space.
    ///
    /// Example: "Hello |" insert John → "Hello @John |"
    private func handleInsertMention(
        currentState: ChatTextInputState?,
        mention: Mention
    ) -> ChatTextInputState {
        guard let currentState else {
            return initialize(from: .empty)
        }

        let mentionText = mentionProcessor.makeMentionAttributedString(for: mention)
        let insertRange = SelectionManager.clamp(
            currentState.selectionRange,
            to: currentState.attributedText.length
        )

        let mutable = NSMutableAttributedString(attributedString: currentState.attributedText)
        mutable.replaceCharacters(in: insertRange, with: mentionText)

        let newSelection = SelectionManager.afterReplacement(
            replacedRange: insertRange,
            replacementLength: mentionText.length
        )

        return ChatTextInputState(
            attributedText: mutable,
            selectionRange: SelectionManager.clamp(newSelection, to: mutable.length)
        )
    }
}
