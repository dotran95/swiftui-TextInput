//
//  ChatTextInputView.swift
//  app
//
//  SwiftUI wrapper around UITextView with one-way data flow:
//  User Action → UITextView Event → EditorEvent → EditorProcessor → State → Render
//

import SwiftUI

struct ChatTextInputView: UIViewRepresentable {

    @Binding var state: ChatTextInputState

    func makeCoordinator() -> TextInputCoordinator {
        TextInputCoordinator(state: $state)
    }

    func makeUIView(context: Context) -> ChatTextView {
        let textView = ChatTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.isScrollEnabled = false
        textView.keyboardDismissMode = .interactive
        textView.autocorrectionType = .yes
        textView.spellCheckingType = .yes
        textView.allowsEditingTextAttributes = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        context.coordinator.attachPasteHandler(to: textView)
        render(state: state, into: textView, coordinator: context.coordinator)

        return textView
    }

    func updateUIView(_ uiView: ChatTextView, context: Context) {
        render(state: state, into: uiView, coordinator: context.coordinator)
    }

  // MARK: - Render

    /// Pushes `ChatTextInputState` into UITextView.
    ///
    /// `isRendering` prevents delegate callbacks from re-entering the processor.
    private func render(
        state: ChatTextInputState,
        into textView: ChatTextView,
        coordinator: TextInputCoordinator
    ) {
        coordinator.beginRendering()
        defer { coordinator.endRendering() }

        // Never overwrite UITextView content during IME marked-text composition.
        let skipContentSync = coordinator.shouldSkipRenderSync(for: textView)

        if !skipContentSync,
           !textView.attributedText.isEqual(to: state.attributedText) {
            textView.attributedText = state.attributedText
        }

        if !skipContentSync,
           textView.selectedRange != state.selectionRange {
            textView.selectedRange = state.selectionRange
        }

        textView.typingAttributes = AttributeBuilder().typingAttributes(
            at: state.selectionRange.location,
            in: state.attributedText
        )
    }
}

// MARK: - Factory helpers

extension EditorProcessor {
    /// Shared processor for constructing initial state outside the view.
    ///
    /// ```swift
    /// let processor = EditorProcessor()
    /// @State var inputState = processor.process(currentState: nil, event: .initialize(draft))
    /// ChatTextInputView(state: $inputState)
    /// ```
    static func makeInitialState(from draft: DraftContent) -> ChatTextInputState {
        EditorProcessor().process(currentState: nil, event: .initialize(draft))
    }

    /// Programmatic mention insertion (events are not exposed on the view).
    static func insertMention(
        _ mention: Mention,
        into state: ChatTextInputState
    ) -> ChatTextInputState {
        EditorProcessor().process(currentState: state, event: .insertMention(mention))
    }
}

#if DEBUG
struct ChatTextInputView_Previews: PreviewProvider {
    struct PreviewContainer: View {
        @State private var state = EditorProcessor.makeInitialState(
            from: DraftContent(
                text: "Hello @John",
                mentions: [
                    DraftMentionMetadata(
                        userId: "123",
                        displayName: "John",
                        range: NSRange(location: 6, length: 5)
                    )
                ],
                markdownSegments: []
            )
        )

        var body: some View {
            ChatTextInputView(state: $state)
                .padding()
        }
    }

    static var previews: some View {
        PreviewContainer()
    }
}
#endif
