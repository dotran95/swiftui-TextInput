# ChatTextInput

SwiftUI editor backed by `UITextView`, designed in the style of Telegram / Slack / Discord.

## Architecture

```
User Action
    ↓
UITextView Event
    ↓
EditorEvent
    ↓
EditorProcessor
    ↓
ChatTextInputState
    ↓
Render UITextView
```

`TextInputCoordinator` never mutates state directly. It only:

1. Emits `EditorEvent`
2. Calls `EditorProcessor`
3. Assigns the result to `@Binding var state`

## Public API

`ChatTextInputView` exposes a single binding:

```swift
ChatTextInputView(state: $inputState)
```

Events are **not** exposed from the view. Typing, delete, selection, mention, and paste are handled internally.

### Initialization

Do **not** construct `ChatTextInputState` directly. Always go through `EditorEvent.initialize`:

```swift
let draft = DraftContent(
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

@State private var inputState = EditorProcessor.makeInitialState(from: draft)

ChatTextInputView(state: $inputState)
```

### Programmatic mention insert

```swift
inputState = EditorProcessor.insertMention(
    Mention(userId: "456", displayName: "Jane"),
    into: inputState
)
```

## State

State is render-only and intentionally minimal:

```swift
struct ChatTextInputState {
    var attributedText: NSAttributedString
    var selectionRange: NSRange   // source of truth for cursor / selection
}
```

Do **not** store mentions, markdown, tokens, or parser output in state. Those belong inside `EditorProcessor`.

## Components

| File | Role |
|------|------|
| `ChatTextInputView` | `UIViewRepresentable` wrapper |
| `TextInputCoordinator` | `UITextViewDelegate` → events |
| `ChatTextView` | `UITextView` subclass with paste override |
| `EditorProcessor` | Single mutation entry point |
| `PasteProcessor` | Clipboard normalization |
| `MentionProcessor` | Mention insert, lookup, atomic delete |
| `MentionParser` | Draft mention metadata → attributes |
| `MarkdownParser` | Inline + draft markdown |
| `AttributeBuilder` | Styling and typing attributes |
| `SelectionManager` | Cursor / selection math |
| `IMECompositionHandler` | Vietnamese / CJK / Korean IME detection |

## Mention attribute

Mentions use a custom attribute:

```swift
NSAttributedString.Key.mentionId  // value: String (userId)
```

Visible text: `@displayName`

Example: `@John` with `mentionId = "123"`.

Mentions survive typing, paste, re-render, and copy. They are **not** stored as plain text only.

## Flows

### 1. Initialize

```
DraftContent → MentionParser → MarkdownParser → ChatTextInputState
```

1. Parent calls `EditorProcessor.makeInitialState(from:)` or `.initialize(draft)`.
2. `MentionParser` reads `draft.text` + `draft.mentions` and applies `mentionId` on each `@displayName` range.
3. `MarkdownParser` applies `draft.markdownSegments` and scans inline syntax (`**bold**`, `*italic*`, `` `code` ``, `~~strike~~`).
4. Returns `ChatTextInputState` with the caret at the **end of text**.

**Cursor**

```
"Hello World"  →  Hello World|
selectionRange = NSRange(location: 11, length: 0)
```

`SelectionManager.atEnd(of:)` places the caret after the last character.

---

### 2. Typing

```
shouldChangeTextIn → .textInput(range, replacement) → EditorProcessor → state → render
```

1. User types → `shouldChangeTextIn` receives `range` and replacement text.
2. Coordinator builds `NSAttributedString` using `typingAttributes` at the cursor.
3. `AttributeBuilder.sanitizeTypingReplacement` strips `mentionId` from typed input so new characters never become fake mentions.
4. `EditorProcessor` replaces the range in `attributedText`.
5. Coordinator returns `false` so `UITextView` does not mutate text itself; the new state is rendered in `updateUIView`.

**Cursor**

```
"Hello |"  + type "A"  →  "Hello A|"

replaceRange.location = 5
replacement.length = 1
selectionRange = NSRange(location: 6, length: 0)
```

`SelectionManager.afterReplacement(replacedRange:replacementLength:)` computes `location + replacementLength`.

Emoji from the iOS keyboard flows through the direct-input path. Vietnamese Telex/VNI uses the IME path (see [Vietnamese & IME input](#vietnamese--ime-input)).

---

### 3. Selection

```
textViewDidChangeSelection → .selectionChanged(range) → clamp → state
```

1. User taps or drags to move the caret or selection.
2. Guard `!isRendering` to avoid feedback during programmatic updates.
3. Skip if the range already matches `state.selectionRange`.
4. `SelectionManager.clamp(range, to: textLength)` keeps the range in bounds.

**Cursor**

`selectionRange` mirrors exactly what `UITextView` reports. It is the source of truth for cursor position.

---

### 4. Mention

#### From draft (initialize)

`MentionParser` attaches `mentionId` to each `@displayName` range defined in `DraftMentionMetadata`.

#### Programmatic insert

```
.insertMention(Mention) → MentionProcessor → replace at selectionRange
```

Inserts `@displayName ` with `mentionId` on `@displayName` only (trailing space has no mention id).

**Cursor**

```
"Hello |"  insert John  →  "Hello @John |"

selectionRange = insertRange.location + mentionText.length
```

#### Atomic delete

`MentionProcessor.expandDeleteRange` treats mentions as single tokens. Deleting one character inside a mention removes the entire mention.

```
"Hello @Jo|hn"  backspace  →  "Hello |"
```

#### Copy / paste

`mentionId` lives on `NSAttributedString`, so `UITextView` preserves it on copy. `PasteProcessor.preserveMentions` keeps `mentionId` and mention styling on paste.

---

### 5. Paste

```
ChatTextView.paste() → onPaste → .paste(content) → PasteProcessor → replace at selectionRange
```

1. `ChatTextView` overrides `paste(_:)` and reads `UIPasteboard` (attributed or plain).
2. `PasteProcessor.normalize`:
   - plain text → base attributes
   - attributed text → keep existing fonts / colors
   - mentions → keep `mentionId`
   - emoji → preserved as UTF-16
3. `MarkdownParser.reparseInline` runs on pasted content.
4. Content replaces the current `selectionRange`.

**Cursor**

```
"Hello |World"  paste "ABC"  at location 6  →  "Hello ABC|World"

selectionRange = 6 + 3 = 9
```

If text is selected, paste replaces the selection first, then places the caret at the end of the pasted content.

---

### 6. Render & loop protection

```
updateUIView → beginRendering() → set attributedText + selectedRange + typingAttributes → endRendering()
```

**Problem:** `updateUIView` sets `selectedRange` → `textViewDidChangeSelection` → `process` → `updateUIView` → loop.

**Solution:** `isRendering` on `TextInputCoordinator`:

| Phase | `isRendering` | Delegate behavior |
|-------|---------------|-------------------|
| Pushing state into `UITextView` | `true` | delegate returns early |
| User interaction | `false` | emits `EditorEvent` normally |

`typingAttributes` is updated from cursor position so characters typed after a mention do **not** inherit `mentionId`.

## Vietnamese & IME input

Returning `false` from `shouldChangeTextIn` blocks **marked-text composition** (`markedTextRange`), which breaks Vietnamese Telex/VNI and other IME keyboards.

### Hybrid typing strategy

| Condition | `shouldChangeTextIn` | Sync path |
|-----------|---------------------|-----------|
| IME language (`vi`, `zh`, `ja`, `ko`) or active marked text | return `true` — UIKit owns mutation | `textViewDidChange` → `.syncFromTextView` |
| Latin / direct input | return `false` — processor owns mutation | `.textInput` / `.deleteBackward` |

### IME flow

```
User types (Vietnamese keyboard)
    ↓
shouldChangeTextIn → return true
    ↓
UITextView marked text (e.g. "uw" composing → "ư")
    ↓
textViewDidChange (markedTextRange != nil) → update selection only
    ↓
User commits composition (markedTextRange == nil)
    ↓
textViewDidChange → .syncFromTextView → EditorProcessor → state
    ↓
updateUIView skips overwrite while markedTextRange is active
```

`IMECompositionHandler` detects:

- `textView.markedTextRange != nil` — active composition
- `textInputMode.primaryLanguage` prefix `vi` / `zh` / `ja` / `ko`
- `isIMEComposing` flag until the committed sync completes

## Markdown

Markdown is applied on **initialize** and **paste**:

- `**bold**`
- `*italic*`
- `` `code` ``
- `~~strikethrough~~`

Draft metadata via `MarkdownSegment` is also supported. Live conversion while typing is intentionally not enabled so cursor math stays stable.

## Future extensions

The architecture is ready for:

- Hashtag
- Quote
- Reply preview
- Link preview

Add new `EditorEvent` cases and processors. `ChatTextInputState` stays limited to `attributedText` + `selectionRange`.
