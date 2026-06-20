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

  // MARK: - UITextViewDelegate

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        // Allow UIKit to proceed while we are pushing rendered state back in.
        guard !isRendering else { return true }

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

    func textViewDidChangeSelection(_ textView: UITextView) {
        guard !isRendering else { return }

        let selected = textView.selectedRange
        guard !SelectionManager.isEqual(selected, state.selectionRange) else { return }

        apply(.selectionChanged(selected))
    }

  // MARK: - Paste

    private func handlePaste(_ content: NSAttributedString) {
        guard !isRendering else { return }
        apply(.paste(content))
    }

  // MARK: - Processing

    private func apply(_ event: EditorEvent) {
        let newState = processor.process(currentState: state, event: event)
        guard newState != state else { return }
        state = newState
    }
}
