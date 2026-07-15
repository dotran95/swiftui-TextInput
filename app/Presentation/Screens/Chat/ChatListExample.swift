//
//  ChatListExample.swift
//  app
//
//  Multi-cell example: text, sticker, and image message cells.
//

import SwiftUI
import UIKit

// MARK: - Model

enum MessageItem: Hashable, ListSizeCacheable {
    case text(id: String, body: String)
    case sticker(id: String, emoji: String)
    case image(id: String, colorHex: String, width: CGFloat, height: CGFloat)

    var id: String {
        switch self {
        case .text(let id, _), .sticker(let id, _), .image(let id, _, _, _):
            return id
        }
    }

    var cacheKey: String {
        switch self {
        case .text(let id, let body):
            return "text|\(id)|\(body)"
        case .sticker(let id, let emoji):
            return "sticker|\(id)|\(emoji)"
        case .image(let id, let colorHex, let width, let height):
            return "image|\(id)|\(colorHex)|\(width)|\(height)"
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MessageItem, rhs: MessageItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum ChatListSection: Hashable {
    case messages
}

// MARK: - Cells

final class TextMessageCell: ListSizingCell {

    static let registration = UICollectionView.CellRegistration<TextMessageCell, MessageItem> { cell, _, item in
        guard case .text(_, let body) = item else { return }
        cell.configure(body: body)
    }

    private let bubbleView = UIView()
    private let messageLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupContent()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupContent()
    }

    override func setupContent() {
        bubbleView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        bubbleView.layer.cornerRadius = 16
        bubbleView.translatesAutoresizingMaskIntoConstraints = false

        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -80),
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10)
        ])
    }

    func configure(body: String) {
        messageLabel.text = body
    }
}

final class StickerMessageCell: ListSizingCell {

    static let registration = UICollectionView.CellRegistration<StickerMessageCell, MessageItem> { cell, _, item in
        guard case .sticker(_, let emoji) = item else { return }
        cell.configure(emoji: emoji)
    }

    private let stickerLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupContent()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupContent()
    }

    override func setupContent() {
        stickerLabel.font = .systemFont(ofSize: 64)
        stickerLabel.textAlignment = .left
        stickerLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stickerLabel)

        NSLayoutConstraint.activate([
            stickerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stickerLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            stickerLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            stickerLabel.widthAnchor.constraint(equalToConstant: 80),
            stickerLabel.heightAnchor.constraint(equalToConstant: 80)
        ])
    }

    func configure(emoji: String) {
        stickerLabel.text = emoji
    }
}

final class ImageMessageCell: ListSizingCell {

    static let registration = UICollectionView.CellRegistration<ImageMessageCell, MessageItem> { cell, _, item in
        guard case .image(_, let colorHex, let width, let height) = item else { return }
        cell.configure(colorHex: colorHex, width: width, height: height)
    }

    private let photoView = UIView()
    private var aspectConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupContent()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupContent()
    }

    override func setupContent() {
        photoView.layer.cornerRadius = 12
        photoView.clipsToBounds = true
        photoView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(photoView)

        NSLayoutConstraint.activate([
            photoView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            photoView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            photoView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            photoView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.55)
        ])
    }

    func configure(colorHex: String, width: CGFloat, height: CGFloat) {
        photoView.backgroundColor = UIColor(hex: colorHex)
        aspectConstraint?.isActive = false
        aspectConstraint = photoView.heightAnchor.constraint(
            equalTo: photoView.widthAnchor,
            multiplier: height / max(width, 1)
        )
        aspectConstraint?.isActive = true
    }
}

// MARK: - Cell Provider

enum ChatListCellProvider {

    static func makeProvider() -> (UICollectionView, IndexPath, MessageItem) -> UICollectionViewCell {
        { collectionView, indexPath, item in
            switch item {
            case .text:
                return collectionView.dequeueConfiguredReusableCell(
                    using: TextMessageCell.registration,
                    for: indexPath,
                    item: item
                )
            case .sticker:
                return collectionView.dequeueConfiguredReusableCell(
                    using: StickerMessageCell.registration,
                    for: indexPath,
                    item: item
                )
            case .image:
                return collectionView.dequeueConfiguredReusableCell(
                    using: ImageMessageCell.registration,
                    for: indexPath,
                    item: item
                )
            }
        }
    }
}

// MARK: - View Model

@MainActor
final class ChatListViewModel: ObservableObject {

    @Published private(set) var snapshot = NSDiffableDataSourceSnapshot<ChatListSection, MessageItem>()

    init() {
        reload(with: Self.makeSampleMessages())
    }

    func reload(with messages: [MessageItem], animated: Bool = false) {
        var newSnapshot = NSDiffableDataSourceSnapshot<ChatListSection, MessageItem>()
        newSnapshot.appendSections([.messages])
        newSnapshot.appendItems(messages, toSection: .messages)
        snapshot = newSnapshot
    }

    func appendRandomMessage() {
        var items = snapshot.itemIdentifiers
        let index = items.count + 1

        let newItem: MessageItem
        switch index % 3 {
        case 0:
            newItem = .sticker(id: UUID().uuidString, emoji: ["😀", "🎉", "🔥", "👍"].randomElement() ?? "😀")
        case 1:
            newItem = .image(
                id: UUID().uuidString,
                colorHex: ["FF3B30", "34C759", "FF9500", "AF52DE"].randomElement() ?? "007AFF",
                width: 4,
                height: 3
            )
        default:
            newItem = .text(
                id: UUID().uuidString,
                body: "New text message #\(index). Multi-cell ListCollectionView dequeues the correct registration per item."
            )
        }

        items.append(newItem)
        reload(with: items, animated: true)
    }

    private static func makeSampleMessages() -> [MessageItem] {
        let longText = """
        This is a long text message to demonstrate dynamic height caching. \
        ListCollectionView supports heterogeneous cells — text, sticker, and image — \
        each with its own UICollectionView.CellRegistration.
        """

        return (1...36).map { index in
            switch index % 3 {
            case 0:
                return .sticker(id: "sticker-\(index)", emoji: ["😀", "🎉", "🔥", "👍", "❤️"][index % 5])
            case 1:
                return .image(
                    id: "image-\(index)",
                    colorHex: ["FF3B30", "34C759", "FF9500", "AF52DE", "30B0C7"][index % 5],
                    width: index.isMultiple(of: 2) ? 16 : 4,
                    height: index.isMultiple(of: 2) ? 9 : 3
                )
            default:
                return .text(id: "text-\(index)", body: index.isMultiple(of: 5) ? longText : "Short message #\(index)")
            }
        }
    }
}

// MARK: - SwiftUI Screen

struct ChatListExampleView: View {

    @StateObject private var viewModel = ChatListViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ListCollectionView(
                snapshot: viewModel.snapshot,
                animated: true,
                cellProvider: ChatListCellProvider.makeProvider(),
                cacheKeyProvider: { $0.cacheKey }
            )

            Divider()

            Button("Add Message") {
                viewModel.appendRandomMessage()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .navigationTitle("Chat (Multi-Cell)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - UIKit Host

final class ChatListExampleViewController: UIHostingController<ChatListExampleView> {

    init() {
        super.init(rootView: ChatListExampleView())
    }

    @MainActor
    dynamic required init?(coder: NSCoder) {
        super.init(coder: coder, rootView: ChatListExampleView())
    }
}

// MARK: - Helpers

private extension UIColor {
    convenience init?(hex: String) {
        var string = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if string.hasPrefix("#") { string.removeFirst() }
        guard string.count == 6, let value = Int(string, radix: 16) else { return nil }

        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
