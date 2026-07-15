//
//  CommentListExample.swift
//  app
//
//  Example screen demonstrating ListCollectionView with dynamic-height comment cells.
//

import SwiftUI
import UIKit

// MARK: - Model

struct CommentItem: Hashable, ListSizeCacheable {
    let id: String
    let author: String
    let text: String
    let timestamp: Date
    let likeCount: Int
    let isExpanded: Bool

    /// Represents every property that affects cell layout.
    var cacheKey: String {
        "\(id)|\(author)|\(text)|\(isExpanded)|\(likeCount)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CommentItem, rhs: CommentItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum CommentListSection: Hashable {
    case main
}

// MARK: - Cell

final class CommentCell: ListSizingCell {

    static let registration = UICollectionView.CellRegistration<CommentCell, CommentItem> { cell, _, item in
        cell.configure(with: item)
    }

    private let avatarView = UIView()
    private let authorLabel = UILabel()
    private let bodyLabel = UILabel()
    private let metaLabel = UILabel()
    private let likeButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupContent()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupContent()
    }

    override func setupContent() {
        avatarView.backgroundColor = .systemBlue
        avatarView.layer.cornerRadius = 18
        avatarView.translatesAutoresizingMaskIntoConstraints = false

        authorLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        authorLabel.numberOfLines = 1
        authorLabel.translatesAutoresizingMaskIntoConstraints = false

        bodyLabel.font = .systemFont(ofSize: 15)
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        metaLabel.font = .systemFont(ofSize: 13)
        metaLabel.textColor = .secondaryLabel
        metaLabel.translatesAutoresizingMaskIntoConstraints = false

        likeButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        likeButton.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(avatarView)
        contentView.addSubview(authorLabel)
        contentView.addSubview(bodyLabel)
        contentView.addSubview(metaLabel)
        contentView.addSubview(likeButton)

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            avatarView.widthAnchor.constraint(equalToConstant: 36),
            avatarView.heightAnchor.constraint(equalToConstant: 36),

            authorLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            authorLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            authorLabel.topAnchor.constraint(equalTo: avatarView.topAnchor),

            bodyLabel.leadingAnchor.constraint(equalTo: authorLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: authorLabel.trailingAnchor),
            bodyLabel.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 4),

            metaLabel.leadingAnchor.constraint(equalTo: authorLabel.leadingAnchor),
            metaLabel.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 8),

            likeButton.leadingAnchor.constraint(equalTo: metaLabel.trailingAnchor, constant: 12),
            likeButton.centerYAnchor.constraint(equalTo: metaLabel.centerYAnchor),

            metaLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    func configure(with item: CommentItem) {
        authorLabel.text = item.author
        bodyLabel.text = item.text
        bodyLabel.numberOfLines = item.isExpanded ? 0 : 3

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        metaLabel.text = formatter.localizedString(for: item.timestamp, relativeTo: Date())

        likeButton.setTitle("♥ \(item.likeCount)", for: .normal)
    }
}

// MARK: - View Model

@MainActor
final class CommentListViewModel: ObservableObject {

    @Published private(set) var snapshot = NSDiffableDataSourceSnapshot<CommentListSection, CommentItem>()

    init() {
        reload(with: Self.makeSampleComments())
    }

    func reload(with comments: [CommentItem], animated: Bool = false) {
        var newSnapshot = NSDiffableDataSourceSnapshot<CommentListSection, CommentItem>()
        newSnapshot.appendSections([.main])
        newSnapshot.appendItems(comments, toSection: .main)
        snapshot = newSnapshot
    }

    func toggleExpanded(for commentID: String) {
        let items = snapshot.itemIdentifiers.map { item -> CommentItem in
            guard item.id == commentID else { return item }
            return CommentItem(
                id: item.id,
                author: item.author,
                text: item.text,
                timestamp: item.timestamp,
                likeCount: item.likeCount,
                isExpanded: !item.isExpanded
            )
        }
        reload(with: items, animated: true)
    }

    func appendComment() {
        var items = snapshot.itemIdentifiers
        let index = items.count + 1
        items.insert(
            CommentItem(
                id: UUID().uuidString,
                author: "Guest \(index)",
                text: "New comment #\(index). ListCollectionView applies diffable snapshot without recreating the collection view.",
                timestamp: Date(),
                likeCount: 0,
                isExpanded: false
            ),
            at: 0
        )
        reload(with: items, animated: true)
    }

    private static func makeSampleComments() -> [CommentItem] {
        let longText = """
        ListCollectionView is designed for very large lists such as chat, feed, and notifications. \
        Size cache ensures each cell is measured only once until its cacheKey changes.
        """

        return (1...40).map { index in
            CommentItem(
                id: "comment-\(index)",
                author: "User \(index)",
                text: index.isMultiple(of: 5) ? longText : "Short comment #\(index)",
                timestamp: Date().addingTimeInterval(TimeInterval(-index * 180)),
                likeCount: index * 3,
                isExpanded: false
            )
        }
    }
}

// MARK: - SwiftUI Screen

struct CommentListExampleView: View {

    @StateObject private var viewModel = CommentListViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ListCollectionView(
                snapshot: viewModel.snapshot,
                animated: true,
                cellRegistration: CommentCell.registration,
                callbacks: ListCollectionViewCallbacks(
                    didSelect: { item in
                        viewModel.toggleExpanded(for: item.id)
                    },
                    prefetch: { items in
                        // Hook for image/text prefetching when needed.
                        _ = items
                    }
                ),
                cacheKeyProvider: { $0.cacheKey }
            )

            Divider()

            Button("Add Comment") {
                viewModel.appendComment()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - UIKit Host

final class CommentListExampleViewController: UIHostingController<CommentListExampleView> {

    init() {
        super.init(rootView: CommentListExampleView())
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder, rootView: CommentListExampleView())
    }
}
