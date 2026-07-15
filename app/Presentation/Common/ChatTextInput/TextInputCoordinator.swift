//
//  TextInputCoordinator.swift
//  app
//
//  Bridges UITextView delegate callbacks → EditorEvent → EditorProcessor → Binding.
//  Never mutates state directly except through the processor result.
//

import SwiftUI

final class TextInputCoordinator: NSObject, UITextViewDelegate {

    @Binding private var state: ChatTextInputState

    private let processor = EditorProcessor()
    private let attributeBuilder = AttributeBuilder()

    /// Guards against render feedback loops:
    /// `updateUIView` → `textViewDidChangeSelection` → `process` → `updateUIView`
    private(set) var isRendering = false

    /// `true` while marked text is active or until the last IME commit is synced.
    private(set) var isIMEComposing = false

    init(state: Binding<ChatTextInputState>) {
        _state = state
    }

    func beginRendering() {
        isRendering = true
    }

    func endRendering() {
        isRendering = false
    }

    func attachPasteHandler(to textView: ChatTextView) {
        textView.onPaste = { [weak self] pasted in
            self?.handlePaste(pasted)
        }
    }

    func shouldSkipRenderSync(for textView: UITextView) -> Bool {
        isIMEComposing || IMECompositionHandler.isActivelyComposing(textView)
    }

  // MARK: - UITextViewDelegate

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        guard !isRendering else { return true }

        // IME keyboards (Vietnamese, CJK, Korean) require UIKit to own text mutation.
        if IMECompositionHandler.shouldDelegateToSystemIME(textView, isComposing: isIMEComposing) {
            return true
        }

        let event: EditorEvent
        if text.isEmpty {
            event = .deleteBackward(range: range)
        } else {
            let attributes = attributeBuilder.typingAttributes(
                at: range.location,
                in: state.attributedText
            )
            let replacement = NSAttributedString(string: text, attributes: attributes)
            event = .textInput(range: range, replacement: replacement)
        }

        apply(event)
        return false
    }

    func textViewDidChange(_ textView: UITextView) {
        guard !isRendering else { return }

        if IMECompositionHandler.isActivelyComposing(textView) {
            // Marked text is visible — only mirror selection, do not overwrite composition.
            isIMEComposing = true
            apply(.selectionChanged(textView.selectedRange))
            return
        }

        isIMEComposing = false
        let content = textView.attributedText ?? NSAttributedString()
        apply(.syncFromTextView(attributedText: content, selection: textView.selectedRange))
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        guard !isRendering else { return }

        let selected = textView.selectedRange
        guard !SelectionManager.isEqual(selected, state.selectionRange) else { return }

        apply(.selectionChanged(selected))
    }

  // MARK: - Paste

    private func handlePaste(_ content: NSAttributedString) {
        guard !isRendering else { return }
        isIMEComposing = false
        apply(.paste(content))
    }

  // MARK: - Processing

    private func apply(_ event: EditorEvent) {
        let newState = processor.process(currentState: state, event: event)
        guard newState != state else { return }
        state = newState
    }
}
