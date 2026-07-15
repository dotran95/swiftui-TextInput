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
    let proposedWidth: CGFloat
    let cacheKey: String?
    let readSize: (String) -> CGSize?
    let writeSize: (CGSize, String) -> Void

    func cachedSize() -> CGSize? {
        guard let cacheKey else { return nil }
        return readSize(cacheKey)
    }

    func store(size: CGSize) {
        guard let cacheKey else { return }
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

// MARK: - Snapshot Apply Policy

/// Controls how often `ListCollectionView` commits snapshots to UIKit.
enum ListSnapshotApplyPolicy: Equatable {
    /// Every SwiftUI update applies immediately.
    case immediate
    /// Merges burst updates on the same run loop — only the latest snapshot is applied.
    case coalesced
    /// Applies once after updates pause for `interval` seconds.
    case debounced(TimeInterval)
}

// MARK: - Coordinator

final class ListCollectionViewCoordinator<Section: Hashable, Item: Hashable>: NSObject {

    typealias CellProvider = (UICollectionView, IndexPath, Item) -> UICollectionViewCell

    private let cellProvider: CellProvider
    private let cacheKeyProvider: (Item) -> String?
    private let applyPolicy: ListSnapshotApplyPolicy

    private(set) var collectionView: UICollectionView!
    private(set) var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private let sizeCache = ListSizeCacheManager<Item>()

    private var callbacks = ListCollectionViewCallbacks<Item>()
    private var lastSnapshot: NSDiffableDataSourceSnapshot<Section, Item>?

    private var isApplying = false
    private var pendingSnapshot: NSDiffableDataSourceSnapshot<Section, Item>?
    private var pendingAnimated = false
    private var isCoalesceScheduled = false
    private var debounceWorkItem: DispatchWorkItem?

    init(
        cellProvider: @escaping CellProvider,
        cacheKeyProvider: ((Item) -> String?)?,
        applyPolicy: ListSnapshotApplyPolicy = .immediate
    ) {
        self.cellProvider = cellProvider
        self.cacheKeyProvider = cacheKeyProvider
        self.applyPolicy = applyPolicy
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
        switch applyPolicy {
        case .immediate:
            performApply(snapshot: snapshot, animated: animated)

        case .coalesced:
            pendingSnapshot = snapshot
            if animated { pendingAnimated = true }

            // First apply must be synchronous so the list is not empty on appear.
            if lastSnapshot == nil {
                pendingSnapshot = nil
                pendingAnimated = false
                performApply(snapshot: snapshot, animated: animated)
                return
            }

            scheduleCoalescedApply()

        case .debounced(let interval):
            pendingSnapshot = snapshot
            if animated { pendingAnimated = true }
            scheduleDebouncedApply(interval: interval)
        }
    }

    // MARK: - Private

    private func scheduleCoalescedApply() {
        guard !isCoalesceScheduled else { return }
        isCoalesceScheduled = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isCoalesceScheduled = false
            guard let snapshot = self.pendingSnapshot else { return }

            self.pendingSnapshot = nil
            let animated = self.pendingAnimated
            self.pendingAnimated = false
            self.performApply(snapshot: snapshot, animated: animated)
        }
    }

    private func scheduleDebouncedApply(interval: TimeInterval) {
        debounceWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self, let snapshot = self.pendingSnapshot else { return }
            self.pendingSnapshot = nil
            let animated = self.pendingAnimated
            self.pendingAnimated = false
            self.performApply(snapshot: snapshot, animated: animated)
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: work)
    }

    private func performApply(
        snapshot: NSDiffableDataSourceSnapshot<Section, Item>,
        animated: Bool
    ) {
        if isApplying {
            pendingSnapshot = snapshot
            if animated { pendingAnimated = true }
            return
        }

        if let lastSnapshot, Self.isEquivalent(lastSnapshot, to: snapshot) {
            return
        }

        isApplying = true
        invalidateChangedItems(between: lastSnapshot, and: snapshot)
        lastSnapshot = snapshot

        dataSource.apply(snapshot, animatingDifferences: animated) { [weak self] in
            guard let self else { return }
            self.sizeCache.removeOrphanedItems(keeping: Set(snapshot.itemIdentifiers))
            self.isApplying = false

            if let pending = self.pendingSnapshot {
                self.pendingSnapshot = nil
                let pendingAnimated = self.pendingAnimated
                self.pendingAnimated = false
                self.performApply(snapshot: pending, animated: pendingAnimated)
            }
        }
    }

    private static func isEquivalent(
        _ lhs: NSDiffableDataSourceSnapshot<Section, Item>,
        _ rhs: NSDiffableDataSourceSnapshot<Section, Item>
    ) -> Bool {
        lhs.sectionIdentifiers == rhs.sectionIdentifiers
            && lhs.itemIdentifiers == rhs.itemIdentifiers
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

        let width = collectionView.bounds.width
            - collectionView.adjustedContentInset.left
            - collectionView.adjustedContentInset.right

        let cacheKey = cacheKeyProvider?(item)

        sizingCell.sizingContext = ListSizingContext(
            proposedWidth: max(width, 1),
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

        let newItems = Set(newSnapshot.itemIdentifiers)

        for item in oldSnapshot.itemIdentifiers where !newItems.contains(item) {
            let oldKey = sizeCache.cacheKey(for: item)
            sizeCache.invalidate(item: item)
            if let oldKey {
                sizeCache.removeCacheKeyIfUnused(oldKey)
            }
        }

        guard let cacheKeyProvider else { return }

        for item in newSnapshot.itemIdentifiers {
            guard oldSnapshot.indexOfItem(item) != nil else { continue }
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
        debounceWorkItem?.cancel()
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
    /// `.coalesced` is recommended for chat/feed with burst updates.
    var applyPolicy: ListSnapshotApplyPolicy = .immediate

    func makeCoordinator() -> ListCollectionViewCoordinator<Section, Item> {
        ListCollectionViewCoordinator(
            cellProvider: cellProvider,
            cacheKeyProvider: cacheKeyProvider,
            applyPolicy: applyPolicy
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
        applyPolicy: ListSnapshotApplyPolicy = .immediate
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
        self.applyPolicy = applyPolicy
    }
}
