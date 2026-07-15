//
//  ListCollectionView.swift
//  app
//
//  High-performance generic UICollectionView bridge for SwiftUI.
//  Uses DiffableDataSource + CompositionalLayout + per-item size cache.
//

import SwiftUI
import UIKit

// MARK: - Size Cache Protocol

/// Items that participate in size caching must expose a key representing
/// every property that affects layout (text, images, expanded state, font, …).
protocol ListSizeCacheable: Equatable {
    var cacheKey: String { get }
}

// MARK: - Size Cache Manager

/// Caches measured cell sizes keyed by `IndexPath` for fast layout lookups.
/// Each entry also stores the item identity and cacheKey so snapshot updates
/// can surgically invalidate only changed items — never the full cache.
final class ListSizeCacheManager<Item: Hashable> {

    private struct Entry {
        let size: CGSize
        let cacheKey: String
        let item: Item
    }

    private var cache: [IndexPath: Entry] = [:]
    private var itemCacheKeys: [Item: String] = [:]

    func size(for indexPath: IndexPath) -> CGSize? {
        cache[indexPath]?.size
    }

    func cacheKey(for indexPath: IndexPath) -> String? {
        cache[indexPath]?.cacheKey
    }

    func cacheKey(for item: Item) -> String? {
        itemCacheKeys[item]
    }

    func store(size: CGSize, cacheKey: String, item: Item, at indexPath: IndexPath) {
        cache[indexPath] = Entry(size: size, cacheKey: cacheKey, item: item)
        itemCacheKeys[item] = cacheKey
    }

    /// Removes cache for a single item. Other entries stay intact.
    func invalidate(item: Item) {
        itemCacheKeys.removeValue(forKey: item)
        cache = cache.filter { $0.value.item != item }
    }

    /// Rebuilds IndexPath keys after diffable apply without clearing valid entries.
    func remapIndexPaths(_ mapping: [IndexPath: Item]) {
        var newCache: [IndexPath: Entry] = [:]
        newCache.reserveCapacity(mapping.count)

        for (indexPath, item) in mapping {
            if let existing = cache[indexPath], existing.item == item {
                newCache[indexPath] = existing
                continue
            }

            if let cacheKey = itemCacheKeys[item],
               let entry = cache.values.first(where: { $0.item == item && $0.cacheKey == cacheKey }) {
                newCache[indexPath] = Entry(size: entry.size, cacheKey: cacheKey, item: item)
            }
        }

        cache = newCache
    }

    func removeOrphanedItems(keeping keptItems: Set<Item>) {
        let orphaned = itemCacheKeys.keys.filter { !keptItems.contains($0) }
        orphaned.forEach { invalidate(item: $0) }
    }
}

// MARK: - Sizing Cell

/// Bridges a cell to the coordinator's size cache without retaining the coordinator.
struct ListSizingContext {
    let indexPath: IndexPath
    let proposedWidth: CGFloat
    let cacheKey: String?
    let readSize: (IndexPath) -> CGSize?
    let readCachedKey: (IndexPath) -> String?
    let writeSize: (CGSize, String, IndexPath) -> Void

    func cachedSize() -> CGSize? {
        guard let cacheKey else { return nil }
        guard readCachedKey(indexPath) == cacheKey else { return nil }
        return readSize(indexPath)
    }

    func store(size: CGSize) {
        guard let cacheKey else { return }
        writeSize(size, cacheKey, indexPath)
    }
}

/// Base cell for dynamic-height lists.
/// Subclass this and build content with AutoLayout in `setupContent()`.
open class ListSizingCell: UICollectionViewCell {

    var sizingContext: ListSizingContext?

    open func setupContent() { }

    open override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        let attributes = layoutAttributes.copy() as! UICollectionViewLayoutAttributes
        let width = sizingContext?.proposedWidth ?? layoutAttributes.size.width

        // Reuse cached size when cacheKey is still valid — avoids AutoLayout pass.
        if let context = sizingContext, let cached = context.cachedSize() {
            attributes.size = CGSize(width: width, height: cached.height)
            return attributes
        }

        let targetSize = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        let measured = contentView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        attributes.size = measured
        sizingContext?.store(size: measured)
        return attributes
    }

    open override func prepareForReuse() {
        super.prepareForReuse()
        sizingContext = nil
    }
}

// MARK: - Delegate Callbacks

struct ListCollectionViewCallbacks<Item: Hashable> {
    var didSelect: ((Item) -> Void)?
    var willDisplay: ((Item, IndexPath) -> Void)?
    var didEndDisplaying: ((Item, IndexPath) -> Void)?
    var prefetch: (([Item]) -> Void)?
    var cancelPrefetch: (([Item]) -> Void)?
    var scrollViewDidScroll: ((UIScrollView) -> Void)?
}

// MARK: - Default Layout

enum ListCollectionViewLayoutFactory {

    /// Vertical list — full width, estimated height for self-sizing cells.
    static func makeDefaultLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(52)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(52)
            )
            let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 0
            return section
        }
    }
}

// MARK: - Coordinator

final class ListCollectionViewCoordinator<
    Section: Hashable,
    Item: Hashable,
    Cell: ListSizingCell
>: NSObject {

    typealias CellProvider = (UICollectionView, IndexPath, Item) -> UICollectionViewCell
    typealias LayoutProvider = (UICollectionView) -> UICollectionViewLayout

    private let cellProvider: CellProvider?
    private let configureCell: ((Cell, IndexPath, Item) -> Void)?
    private let layoutProvider: LayoutProvider?
    private let cacheKeyProvider: (Item) -> String?

    private(set) var collectionView: UICollectionView!
    private(set) var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private let sizeCache = ListSizeCacheManager<Item>()

    private var cellRegistration: UICollectionView.CellRegistration<Cell, Item>!
    private var callbacks = ListCollectionViewCallbacks<Item>()
    private var lastSnapshot: NSDiffableDataSourceSnapshot<Section, Item>?

    init(
        cellProvider: CellProvider? = nil,
        configureCell: ((Cell, IndexPath, Item) -> Void)? = nil,
        layoutProvider: LayoutProvider?,
        cacheKeyProvider: ((Item) -> String?)?
    ) {
        self.cellProvider = cellProvider
        self.configureCell = configureCell
        self.layoutProvider = layoutProvider
        self.cacheKeyProvider = cacheKeyProvider
        super.init()
    }

    func attach(to collectionView: UICollectionView) {
        self.collectionView = collectionView
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.backgroundColor = .clear

        makeCellRegistration()
        makeDataSource()
    }

    func updateCallbacks(_ callbacks: ListCollectionViewCallbacks<Item>) {
        self.callbacks = callbacks
    }

    func apply(
        snapshot: NSDiffableDataSourceSnapshot<Section, Item>,
        animated: Bool
    ) {
        invalidateChangedItems(between: lastSnapshot, and: snapshot)
        lastSnapshot = snapshot

        dataSource.apply(snapshot, animatingDifferences: animated) { [weak self] in
            self?.remapSizeCache(for: snapshot)
        }
    }

    // MARK: - Private

    private func makeCellRegistration() {
        cellRegistration = UICollectionView.CellRegistration<Cell, Item> { [weak self] cell, indexPath, item in
            guard let self else { return }

            if let configureCell = self.configureCell {
                configureCell(cell, indexPath, item)
            } else if let cellProvider = self.cellProvider {
                let template = cellProvider(self.collectionView, indexPath, item)
                if template !== cell {
                    Self.migrateContent(from: template, to: cell)
                }
            }

            self.attachSizing(to: cell, indexPath: indexPath, item: item)
        }
    }

    private func makeDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, item in
            guard let self else { return UICollectionViewCell() }
            return collectionView.dequeueConfiguredReusableCell(
                using: self.cellRegistration,
                for: indexPath,
                item: item
            )
        }
    }

    private func attachSizing(to cell: UICollectionViewCell, indexPath: IndexPath, item: Item) {
        guard let sizingCell = cell as? ListSizingCell else { return }

        let width = collectionView.bounds.width
            - collectionView.adjustedContentInset.left
            - collectionView.adjustedContentInset.right

        let cacheKey = cacheKeyProvider?(item)

        sizingCell.sizingContext = ListSizingContext(
            indexPath: indexPath,
            proposedWidth: max(width, 1),
            cacheKey: cacheKey,
            readSize: { [weak self] path in
                self?.sizeCache.size(for: path)
            },
            readCachedKey: { [weak self] path in
                self?.sizeCache.cacheKey(for: path)
            },
            writeSize: { [weak self] size, key, path in
                self?.sizeCache.store(size: size, cacheKey: key, item: item, at: path)
            }
        )
    }

    private func invalidateChangedItems(
        between oldSnapshot: NSDiffableDataSourceSnapshot<Section, Item>?,
        and newSnapshot: NSDiffableDataSourceSnapshot<Section, Item>
    ) {
        guard let oldSnapshot else { return }

        let newItems = Set(newSnapshot.itemIdentifiers)

        for item in oldSnapshot.itemIdentifiers where !newItems.contains(item) {
            sizeCache.invalidate(item: item)
        }

        guard let cacheKeyProvider else { return }

        for item in newSnapshot.itemIdentifiers {
            guard oldSnapshot.indexOfItem(item) != nil else { continue }
            let newKey = cacheKeyProvider(item)
            if let newKey,
               let oldKey = sizeCache.cacheKey(for: item),
               oldKey != newKey {
                sizeCache.invalidate(item: item)
            }
        }
    }

    private func remapSizeCache(for snapshot: NSDiffableDataSourceSnapshot<Section, Item>) {
        var mapping: [IndexPath: Item] = [:]
        mapping.reserveCapacity(snapshot.numberOfItems)

        for (sectionIndex, section) in snapshot.sectionIdentifiers.enumerated() {
            for (itemIndex, item) in snapshot.itemIdentifiers(inSection: section).enumerated() {
                mapping[IndexPath(item: itemIndex, section: sectionIndex)] = item
            }
        }

        sizeCache.remapIndexPaths(mapping)
        sizeCache.removeOrphanedItems(keeping: Set(snapshot.itemIdentifiers))
    }

    private static func migrateContent(from source: UICollectionViewCell, to destination: UICollectionViewCell) {
        destination.contentConfiguration = source.contentConfiguration
        destination.backgroundConfiguration = source.backgroundConfiguration

        destination.contentView.subviews.forEach { $0.removeFromSuperview() }
        source.contentView.subviews.forEach { subview in
            subview.removeFromSuperview()
            destination.contentView.addSubview(subview)
        }
    }

    deinit {
        collectionView?.delegate = nil
        collectionView?.prefetchDataSource = nil
    }
}

// MARK: - UICollectionViewDelegate

extension ListCollectionViewCoordinator: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        callbacks.didSelect?(item)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        callbacks.willDisplay?(item, indexPath)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didEndDisplaying cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        callbacks.didEndDisplaying?(item, indexPath)
    }
}

// MARK: - Prefetching

extension ListCollectionViewCoordinator: UICollectionViewDataSourcePrefetching {

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let items = indexPaths.compactMap { dataSource.itemIdentifier(for: $0) }
        guard !items.isEmpty else { return }
        callbacks.prefetch?(items)
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let items = indexPaths.compactMap { dataSource.itemIdentifier(for: $0) }
        guard !items.isEmpty else { return }
        callbacks.cancelPrefetch?(items)
    }
}

// MARK: - UIScrollViewDelegate

extension ListCollectionViewCoordinator: UIScrollViewDelegate {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        callbacks.scrollViewDidScroll?(scrollView)
    }
}

// MARK: - SwiftUI Bridge

struct ListCollectionView<
    Section: Hashable,
    Item: Hashable,
    Cell: ListSizingCell
>: UIViewRepresentable {

    var snapshot: NSDiffableDataSourceSnapshot<Section, Item>
    var animated: Bool = true
    var layoutProvider: ((UICollectionView) -> UICollectionViewLayout)?
    var cellProvider: ((UICollectionView, IndexPath, Item) -> UICollectionViewCell)?
    var configureCell: ((Cell, IndexPath, Item) -> Void)?
    var callbacks: ListCollectionViewCallbacks<Item> = .init()
    var cacheKeyProvider: ((Item) -> String?)?

    func makeCoordinator() -> ListCollectionViewCoordinator<Section, Item, Cell> {
        ListCollectionViewCoordinator(
            cellProvider: cellProvider,
            configureCell: configureCell,
            layoutProvider: layoutProvider,
            cacheKeyProvider: cacheKeyProvider
        )
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = layoutProvider?(UICollectionView())
            ?? ListCollectionViewLayoutFactory.makeDefaultLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.keyboardDismissMode = .onDrag
        collectionView.alwaysBounceVertical = true
        context.coordinator.attach(to: collectionView)
        context.coordinator.apply(snapshot: snapshot, animated: false)
        return collectionView
    }

    func updateUIView(_ uiView: UICollectionView, context: Context) {
        context.coordinator.updateCallbacks(callbacks)
        context.coordinator.apply(snapshot: snapshot, animated: animated)
    }
}

// MARK: - Convenience Initializers

extension ListCollectionView {

    /// Preferred for production — configures the dequeued reusable cell in place.
    init(
        snapshot: NSDiffableDataSourceSnapshot<Section, Item>,
        animated: Bool = true,
        layoutProvider: ((UICollectionView) -> UICollectionViewLayout)? = nil,
        configureCell: @escaping (Cell, IndexPath, Item) -> Void,
        callbacks: ListCollectionViewCallbacks<Item> = .init(),
        cacheKeyProvider: ((Item) -> String?)? = nil
    ) {
        self.snapshot = snapshot
        self.animated = animated
        self.layoutProvider = layoutProvider
        self.cellProvider = nil
        self.configureCell = configureCell
        self.callbacks = callbacks
        self.cacheKeyProvider = cacheKeyProvider
    }

    /// Compatible with the requested API. Allocates a template cell per bind — use `configureCell` when possible.
    init(
        snapshot: NSDiffableDataSourceSnapshot<Section, Item>,
        animated: Bool = true,
        layoutProvider: ((UICollectionView) -> UICollectionViewLayout)? = nil,
        cellProvider: @escaping (UICollectionView, IndexPath, Item) -> UICollectionViewCell,
        callbacks: ListCollectionViewCallbacks<Item> = .init(),
        cacheKeyProvider: ((Item) -> String?)? = nil
    ) {
        self.snapshot = snapshot
        self.animated = animated
        self.layoutProvider = layoutProvider
        self.cellProvider = cellProvider
        self.configureCell = nil
        self.callbacks = callbacks
        self.cacheKeyProvider = cacheKeyProvider
    }
}
