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
/// every property that affects layout (text, images, expanded state, font, width, …).
/// Cache is keyed by this string — same cacheKey at any IndexPath shares one size.
protocol ListSizeCacheable: Equatable {
    var cacheKey: String { get }
}

// MARK: - Size Cache Manager

/// Caches measured cell sizes keyed by `cacheKey` only.
/// Same content at different IndexPaths reuses one cached size.
/// Item → cacheKey mapping is kept only for surgical invalidation on snapshot updates.
final class ListSizeCacheManager<Item: Hashable> {

    private var cache: [String: CGSize] = [:]
    private var itemCacheKeys: [Item: String] = [:]

    func size(for cacheKey: String) -> CGSize? {
        cache[cacheKey]
    }

    func cacheKey(for item: Item) -> String? {
        itemCacheKeys[item]
    }

    func store(size: CGSize, cacheKey: String, item: Item) {
        itemCacheKeys[item] = cacheKey
        cache[cacheKey] = size
    }

    /// Drops item tracking. Cache entry stays if other items share the same cacheKey.
    func invalidate(item: Item) {
        itemCacheKeys.removeValue(forKey: item)
    }

    /// Removes a cached size when no item references it anymore.
    func removeCacheKeyIfUnused(_ cacheKey: String) {
        guard !itemCacheKeys.values.contains(cacheKey) else { return }
        cache.removeValue(forKey: cacheKey)
    }

    func removeOrphanedItems(keeping keptItems: Set<Item>) {
        let orphaned = itemCacheKeys.keys.filter { !keptItems.contains($0) }
        orphaned.forEach { item in
            let key = itemCacheKeys[item]
            invalidate(item: item)
            if let key {
                removeCacheKeyIfUnused(key)
            }
        }
    }
}

// MARK: - Sizing Cell

/// Bridges a cell to the coordinator's size cache without retaining the coordinator.
struct ListSizingContext {
    let cacheKey: String?
    let readSize: (String) -> CGSize?
    let writeSize: (CGSize, String) -> Void

    func cachedSize() -> CGSize? {
        guard let cacheKey else { return nil }
        return readSize(cacheKey)
    }

    func store(size: CGSize, width: CGFloat) {
        guard let cacheKey, width > 1 else { return }
        writeSize(size, cacheKey)
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
        let width = Self.resolvedWidth(
            layoutAttributes: layoutAttributes,
            collectionView: collectionView
        )

        // Layout not ready yet — skip measure/cache to avoid poisoning the cache.
        guard width > 1 else { return attributes }

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
        sizingContext?.store(size: measured, width: width)
        return attributes
    }

    /// Prefer layout-provided width; fall back to collection view bounds after layout pass.
    private static func resolvedWidth(
        layoutAttributes: UICollectionViewLayoutAttributes,
        collectionView: UICollectionView?
    ) -> CGFloat {
        let layoutWidth = layoutAttributes.size.width
        if layoutWidth > 1 { return layoutWidth }

        guard let collectionView else { return layoutWidth }

        let boundsWidth = collectionView.bounds.width
            - collectionView.adjustedContentInset.left
            - collectionView.adjustedContentInset.right
        if boundsWidth > 1 { return boundsWidth }

        return layoutWidth
    }

    open override func prepareForReuse() {
        super.prepareForReuse()
        sizingContext = nil
    }
}

// MARK: - Scroll Target

/// Request to scroll the list to a specific item.
struct ListScrollTarget<Item: Hashable>: Equatable {
    var item: Item
    var position: UICollectionView.ScrollPosition = .bottom
    var animated: Bool = true
    /// Changes on each request so scrolling to the same item can be triggered again.
    var id: UUID = UUID()

    static func bottom(_ item: Item, animated: Bool = true) -> ListScrollTarget {
        ListScrollTarget(item: item, position: .bottom, animated: animated)
    }

    static func top(_ item: Item, animated: Bool = true) -> ListScrollTarget {
        ListScrollTarget(item: item, position: .top, animated: animated)
    }

    static func center(_ item: Item, animated: Bool = true) -> ListScrollTarget {
        ListScrollTarget(item: item, position: .centeredVertically, animated: animated)
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

final class ListCollectionViewCoordinator<Section: Hashable, Item: Hashable>: NSObject {

    typealias CellProvider = (UICollectionView, IndexPath, Item) -> UICollectionViewCell

    private let cellProvider: CellProvider
    private let cacheKeyProvider: (Item) -> String?

    private(set) var collectionView: UICollectionView!
    private(set) var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private let sizeCache = ListSizeCacheManager<Item>()

    private var callbacks = ListCollectionViewCallbacks<Item>()
    private var lastSnapshot: NSDiffableDataSourceSnapshot<Section, Item>?
    private var pendingScrollTarget: ListScrollTarget<Item>?
    private var lastHandledScrollID: UUID?

    init(
        cellProvider: @escaping CellProvider,
        cacheKeyProvider: ((Item) -> String?)?
    ) {
        self.cellProvider = cellProvider
        self.cacheKeyProvider = cacheKeyProvider
        super.init()
    }

    func attach(to collectionView: UICollectionView) {
        self.collectionView = collectionView
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.backgroundColor = .clear
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
            guard let self else { return }
            self.sizeCache.removeOrphanedItems(keeping: Set(snapshot.itemIdentifiers))
            self.performPendingScrollIfNeeded()
        }
    }

    func setScrollTarget(_ target: ListScrollTarget<Item>?) {
        guard let target else { return }
        guard target.id != lastHandledScrollID else { return }

        pendingScrollTarget = target
        performPendingScrollIfNeeded()
    }

    // MARK: - Private

    private func performPendingScrollIfNeeded() {
        guard let target = pendingScrollTarget else { return }
        guard let indexPath = dataSource.indexPath(for: target.item) else { return }

        pendingScrollTarget = nil
        lastHandledScrollID = target.id

        collectionView.layoutIfNeeded()
        collectionView.scrollToItem(at: indexPath, at: target.position, animated: target.animated)
    }

    // MARK: - Data Source

    private func makeDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, item in
            guard let self else { return UICollectionViewCell() }

            // Caller owns CellRegistration(s) and dequeues the correct cell type.
            let cell = self.cellProvider(collectionView, indexPath, item)
            self.attachSizing(to: cell, indexPath: indexPath, item: item)
            return cell
        }
    }

    private func attachSizing(to cell: UICollectionViewCell, indexPath: IndexPath, item: Item) {
        guard let sizingCell = cell as? ListSizingCell else { return }

        let cacheKey = cacheKeyProvider?(item)

        sizingCell.sizingContext = ListSizingContext(
            cacheKey: cacheKey,
            readSize: { [weak self] key in
                self?.sizeCache.size(for: key)
            },
            writeSize: { [weak self] size, key in
                self?.sizeCache.store(size: size, cacheKey: key, item: item)
            }
        )
    }

    private func invalidateChangedItems(
        between oldSnapshot: NSDiffableDataSourceSnapshot<Section, Item>?,
        and newSnapshot: NSDiffableDataSourceSnapshot<Section, Item>
    ) {
        guard let oldSnapshot else { return }

        let oldItemsSet = Set(oldSnapshot.itemIdentifiers)
        let newItemsSet = Set(newSnapshot.itemIdentifiers)
        let deletedItems = oldItemsSet.subtracting(newItemsSet)

        for item in deletedItems {
            let oldKey = sizeCache.cacheKey(for: item)
            sizeCache.invalidate(item: item)
            if let oldKey {
                sizeCache.removeCacheKeyIfUnused(oldKey)
            }
        }

        guard let cacheKeyProvider else { return }

        let persistedItems = oldItemsSet.intersection(newItemsSet)
        for item in persistedItems {
            let newKey = cacheKeyProvider(item)
            if let newKey,
               let oldKey = sizeCache.cacheKey(for: item),
               oldKey != newKey {
                sizeCache.invalidate(item: item)
                sizeCache.removeCacheKeyIfUnused(oldKey)
            }
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

struct ListCollectionView<Section: Hashable, Item: Hashable>: UIViewRepresentable {

    var snapshot: NSDiffableDataSourceSnapshot<Section, Item>
    var animated: Bool = true
    var layoutProvider: ((UICollectionView) -> UICollectionViewLayout)?
    var cellProvider: (UICollectionView, IndexPath, Item) -> UICollectionViewCell
    var callbacks: ListCollectionViewCallbacks<Item> = .init()
    var cacheKeyProvider: ((Item) -> String?)?
    /// Set from SwiftUI to scroll to a specific item. Use a new `id` to re-trigger.
    var scrollTarget: ListScrollTarget<Item>?

    func makeCoordinator() -> ListCollectionViewCoordinator<Section, Item> {
        ListCollectionViewCoordinator(
            cellProvider: cellProvider,
            cacheKeyProvider: cacheKeyProvider
        )
    }

    func makeUIView(context: Context) -> UICollectionView {
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: ListCollectionViewLayoutFactory.makeDefaultLayout()
        )

        if let layoutProvider {
            collectionView.collectionViewLayout = layoutProvider(collectionView)
        }

        collectionView.keyboardDismissMode = .onDrag
        collectionView.alwaysBounceVertical = true
        context.coordinator.attach(to: collectionView)
        context.coordinator.apply(snapshot: snapshot, animated: false)
        return collectionView
    }

    func updateUIView(_ uiView: UICollectionView, context: Context) {
        context.coordinator.updateCallbacks(callbacks)
        context.coordinator.apply(snapshot: snapshot, animated: animated)
        context.coordinator.setScrollTarget(scrollTarget)
    }
}

// MARK: - Single-Cell Convenience

extension ListCollectionView {

    /// Convenience for screens with a single cell type.
    /// Configuration happens inside `UICollectionView.CellRegistration`.
    init<Cell: ListSizingCell>(
        snapshot: NSDiffableDataSourceSnapshot<Section, Item>,
        animated: Bool = true,
        layoutProvider: ((UICollectionView) -> UICollectionViewLayout)? = nil,
        cellRegistration: UICollectionView.CellRegistration<Cell, Item>,
        callbacks: ListCollectionViewCallbacks<Item> = .init(),
        cacheKeyProvider: ((Item) -> String?)? = nil,
        scrollTarget: ListScrollTarget<Item>? = nil
    ) {
        self.snapshot = snapshot
        self.animated = animated
        self.layoutProvider = layoutProvider
        self.cellProvider = { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(
                using: cellRegistration,
                for: indexPath,
                item: item
            )
        }
        self.callbacks = callbacks
        self.cacheKeyProvider = cacheKeyProvider
        self.scrollTarget = scrollTarget
    }
}
