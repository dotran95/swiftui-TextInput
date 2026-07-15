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

    func shouldSkipRenderSync(for textView: UITextView) -> Bool {
        IMECompositionHandler.isActivelyComposing(textView)
    }

  // MARK: - UITextViewDelegate

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        guard !isRendering else { return true }

        if text.isEmpty {
            // Delete: processor handles atomic mention removal.
            apply(.deleteBackward(range: range))
            return false
        }

        // Insert / transform: UITextView must own mutation.
        //
        // Vietnamese Telex/VNI transforms existing characters in-place
        // (markedTextRange stays nil). Returning false blocks that transform chain.
        let sourceText = textView.attributedText ?? state.attributedText
        textView.typingAttributes = attributeBuilder.typingAttributes(
            at: range.location,
            in: sourceText
        )
        return true
    }

    func textViewDidChange(_ textView: UITextView) {
        guard !isRendering else { return }

        // CJK only: marked text is visible — mirror selection until commit.
        if IMECompositionHandler.isActivelyComposing(textView) {
            apply(.selectionChanged(textView.selectedRange))
            return
        }

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
        apply(.paste(content))
    }

  // MARK: - Processing

    private func apply(_ event: EditorEvent) {
        let newState = processor.process(currentState: state, event: event)
        guard newState != state else { return }
        state = newState
    }
}
