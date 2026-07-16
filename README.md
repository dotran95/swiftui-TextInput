# ios_template

Using Clean Architecture + MVVM + Rxswift

# Setup
1. Xcode: 15.3
2. Cocoapod: 1.15.2
3. Ruby version: 3.3.4

# Folder Structure

Here is the core folder structure for the application:

```text
App/
|- Application
|- Config
|- Common
|- Data
|- Domain
|- Presentation
|- Manager
|- Rx
|- Extensions
|- Resources
```

## Important components 

### Config Folder

Contains the different configuration files for development, staging, and production environments. 

We can change information such as:
```text
APP_NAME=App (dev)
APP_VERSION=1.0.0
APP_BUNDLE_ID=com.dotn.app.dev
APP_SCHEME=https
APP_DOMAIN=dummyjson.com
```

Additionally, we can change Firebase configuration information at **root/Firebase** folder

### Clean Architecture
```text
|- Data
|   - Database
|   - DataSource
|   - Logging
|   - Networking
|   - Repositories
|- Domain
|   - Entities
|   - Repositories
|   - Usecases
|- Presentation
|   - Storyboard
|   - Screens
```

#### Data: 

The `Data` folder handles all data-related aspects of your application.

- **Database** Contains code related to local database management

- **DataSource** Includes classes responsible for providing data to the application.

- **Logging**: Logging application activities and debugging information.

- **Networking**: For making network requests, handling responses

- **Repositories**: Contains repository classes that abstract the data access logic

#### Domain
The `Domain` folder defines the core business logic and domain-specific entities.

- **Entities**: Models representing core business objects

- **Repositories**: Contains repository protocols that define the contract for data access operations

- **Usecases**: Contains the business logic of the application

#### Presentation
The `Presentation` folder deals with the user interface and user interaction aspects of the application.

- **Storyboard**: Storyboards define the layout and flow of the app’s screens.

- **Screens**: Includes code for individual screens or view controllers


## Things to consider

### 1. How to create a screen

Includes 3 files: ViewController, ViewModel, DIContainer

Eg. app/Presentation/Screens/Splash

**SplashVc.swift**

```swift
class SplashVc: ViewController<SplashViewModel> {

    override func bindViewModel() {
        super.bindViewModel()
        guard let vm = viewModel else { return }
        // Contains the binding data logic between UI and ViewModel
    }
}
```

**SplashViewModel.swift**

```swift
import RxSwift
import RxCocoa

class SplashViewModel: ViewModel, ViewModelType {

    // MARK: - Properties
    private let userUsecase: GetUserUsecaseProtocol

    struct Input { }

    struct Output {
        let loggedIn: PublishRelay<Bool>
    }

    // MARK: - Init
    init(userUsecase: GetUserUsecaseProtocol) {
        self.userUsecase = userUsecase
    }

    func transform(input: Input) -> Output {
        return Output(loggedIn: loggedIn)
    }
}
```

**SplashDIContainer.swift**

```swift
class SplashDIContainer {

    // Initializing UIviewController with corresponding viewmodel and usecase information.
    static func makeViewController() -> SplashVc {

        // Get UI from storyboard
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        // Dependencies Container of application
        let container = Application.shared.appContainer

        // Get usecase instance of `GetUserUsecaseProtocol`
        guard let usecase = container.resolve(GetUserUsecaseProtocol.self),
                let vc = storyboard.instantiateViewController(withIdentifier: "SplashVc") as? SplashVc else {
            fatalError("SplashDIContainer not found")
        }

        // Create viewmodel with userUsecase
        let viewModel = SplashViewModel(userUsecase: usecase)

        vc.viewModel = viewModel
        return vc
    }

}
```

```swift
let vc = SplashDIContainer.makeViewController()
self.navigationBar.push(vc, animated: true)
```

### 2. How to create network request

File: **app/Data/Networking/Apis.swift**

```swift
enum Apis {
    case getUserInfo
    case login(body: Encodable)
}

extension Apis: TargetType, AccessTokenAuthorizable {
    var authorizationType: Moya.AuthorizationType? {
        switch self {
        case .login: return .none
        case .getUserInfo: return .bearer
        }
    }

    var baseURL: URL {URL(string: Configs.share.baseUrl)!}

    var path: String {
        switch self {
        case .login: return "/auth/login"
        case .getUserInfo: return "/auth/me"
        }
    }

    var method: Moya.Method {
        switch self {
        case .login: return .post
        case .getUserInfo: return .get
        }
    }

    var task: Moya.Task {
        switch self {
        case .login(let body): return .requestJSONEncodable(body)
        case .getUserInfo: return .requestPlain
        }
    }

    var headers: [String: String]? { nil }
}

```

### 3. Dependencies Ịnjection
File: **app/Application/Container.swift**
```swift
struct DIContainer {
    private let container: Container

    func resolve<Service>(_ serviceType: Service.Type) -> Service? {
        return container.resolve(serviceType)
    }

    init() {
        container = Container()

        // MARK: - DataSources
        container.register(RemoteDataSourceProtocol.self) { _ in RemoteDataSourceImpl() }

        // MARK: - Repositoris
        container.register(UserRepositoryProtocol.self) { r in UserRepositoryImpl(remoteDataSource: r.resolve(RemoteDataSourceProtocol.self)!) }

        container.register(AuthRepositoryProtocol.self) { r in AuthRepositoryImpl(remoteDataSource: r.resolve(RemoteDataSourceProtocol.self)!) }

        // MARK: - Usecases
        container.register(GetUserUsecaseProtocol.self) { r in GetUserUsecaseImpl(repository: r.resolve(UserRepositoryProtocol.self)!) }

        container.register(LoginUsecaseProtocol.self) { r in LoginUsecaseImpl(repository: r.resolve(AuthRepositoryProtocol.self)!) }
    }

}

Usage: 
let remoteDatasource Application.shared.appContainer.resolve(RemoteDataSourceProtocol.self)
```

---

## ListCollectionView — AI Implementation Guide

> **Audience:** AI agents implementing large, performant lists (chat, comments, feed, notifications) in this repo.
> **Component path:** `app/Presentation/Components/ListCollectionView/ListCollectionView.swift`
> **Working examples:** `CommentListExample.swift` (single cell), `ChatListExample.swift` (multi-cell + scroll)

### What it is

`ListCollectionView` is a generic `UIViewRepresentable` bridge from SwiftUI to `UICollectionView`, built on:

- `UICollectionViewDiffableDataSource` — snapshot diffing, **never** `reloadData()`
- `UICollectionViewCompositionalLayout` — estimated height + self-sizing cells
- `UICollectionView.CellRegistration` — caller owns cell registrations
- Size cache keyed by `cacheKey` (not `IndexPath`) — measure once per content identity

Use this instead of SwiftUI `List` / `LazyVStack` when you need UIKit-level performance for thousands of dynamic-height cells.

### Architecture

```text
SwiftUI View
  └── ListCollectionView<Section, Item>          (UIViewRepresentable)
        └── ListCollectionViewCoordinator        (delegate, prefetch, scroll)
              ├── UICollectionViewDiffableDataSource<Section, Item>
              ├── ListSizeCacheManager<Item>     (cacheKey → CGSize)
              └── cellProvider closure           (caller-defined dequeue logic)
```

**Key types:**

| Type | Role |
|------|------|
| `ListSizeCacheable` | Protocol: item exposes `cacheKey` for size cache |
| `ListSizingCell` | Base `UICollectionViewCell` with auto-measure + cache integration |
| `ListScrollTarget<Item>` | Declarative scroll-to-item API from SwiftUI |
| `ListCollectionViewCallbacks<Item>` | didSelect, willDisplay, prefetch, scroll |
| `ListCollectionViewLayoutFactory` | Default single-column estimated layout |

### Implementation checklist

When adding a new list screen, create these pieces **in order**:

1. **Section enum** — `Hashable` (can be single `.main` or multiple sections)
2. **Item model** — `Hashable` + `ListSizeCacheable` with correct `cacheKey`
3. **Cell class(es)** — subclass `ListSizingCell`, Auto Layout in `setupContent()`
4. **CellRegistration(s)** — `static let registration = UICollectionView.CellRegistration<...>`
5. **ViewModel** — `@Published var snapshot: NSDiffableDataSourceSnapshot<Section, Item>`
6. **SwiftUI screen** — embed `ListCollectionView`, pass snapshot + provider
7. **UIKit host** — `UIHostingController<YourView>` for Navigator integration
8. **Xcode project** — add new `.swift` files to `app.xcodeproj/project.pbxproj` Sources build phase
9. **Navigator** — add scene case in `Navigator.swift`, wire from caller screen

### Step 1 — Item model rules

```swift
struct MyItem: Hashable, ListSizeCacheable {
    let id: String
    let text: String
    let isExpanded: Bool

    // MUST include every property that affects cell height/layout
    var cacheKey: String { "\(id)|\(text)|\(isExpanded)" }

    // Hash/Equatable by stable id only (diffable reconfigures via cacheKey invalidation)
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}
```

**`cacheKey` rules (critical):**

- Include **all** layout-affecting fields (text, expanded state, image dimensions, etc.)
- If text wrap depends on container width, **include width** in `cacheKey` (rotation / split view)
- When content changes, create a **new item value** with updated fields → new `cacheKey` → auto re-measure
- Do **not** key cache by `IndexPath` — same content at different positions must reuse size

### Step 2 — Cell rules

```swift
final class MyCell: ListSizingCell {
    static let registration = UICollectionView.CellRegistration<MyCell, MyItem> { cell, _, item in
        cell.configure(with: item)
    }

    override func setupContent() {
        // Build subviews + NSLayoutConstraint here (once)
        // Use contentView as root; pin bottom constraint for vertical self-sizing
    }

    func configure(with item: MyItem) {
        // Update labels/images only — no frame/layoutIfNeeded hacks
    }
}
```

**Cell DO:**
- Subclass `ListSizingCell` for dynamic height
- Use Auto Layout with a complete vertical constraint chain to `contentView.bottomAnchor`
- Set `numberOfLines = 0` on multi-line labels

**Cell DO NOT:**
- Override `preferredLayoutAttributesFitting` unless you have a very specific reason
- Call `layoutIfNeeded()` / set explicit `frame` in `configure`
- Use `UITableViewCell` or plain `UICollectionViewCell` when height is dynamic (cache won't attach)

### Step 3 — ViewModel snapshot rules

```swift
@MainActor
final class MyListViewModel: ObservableObject {
    @Published private(set) var snapshot = NSDiffableDataSourceSnapshot<MySection, MyItem>()

    func reload(with items: [MyItem], animated: Bool = false) {
        var newSnapshot = NSDiffableDataSourceSnapshot<MySection, MyItem>()
        newSnapshot.appendSections([.main])
        newSnapshot.appendItems(items, toSection: .main)
        snapshot = newSnapshot
    }
}
```

**Snapshot rules:**
- `Item` identifiers must be **globally unique** across all sections (DiffableDataSource requirement)
- Prefer rebuilding snapshot for small/medium lists; for very large lists consider incremental `appendItems` / `deleteItems`
- To update one item's layout: replace item in array with new value (new `cacheKey`), then re-apply snapshot
- `isSnapshotEquivalent` skips apply when section + item order unchanged — ensure item **values** that change layout produce new `cacheKey`

### Pattern A — Single cell type (comments, feed)

Reference: `app/Presentation/Screens/Comment/CommentListExample.swift`

```swift
ListCollectionView(
    snapshot: viewModel.snapshot,
    animated: true,
    cellRegistration: CommentCell.registration,
    callbacks: ListCollectionViewCallbacks(
        didSelect: { item in viewModel.toggleExpanded(for: item.id) },
        prefetch: { items in /* prefetch images/text */ }
    ),
    cacheKeyProvider: { $0.cacheKey }
)
```

Use `cellRegistration:` convenience init when all items share one cell type.

### Pattern B — Multi-cell / heterogeneous (chat)

Reference: `app/Presentation/Screens/Chat/ChatListExample.swift`

```swift
// 1. One CellRegistration per cell type
// 2. Central cellProvider switches on item

enum MyCellProvider {
    static func makeProvider() -> (UICollectionView, IndexPath, MyItem) -> UICollectionViewCell {
        { collectionView, indexPath, item in
            switch item {
            case .text:
                return collectionView.dequeueConfiguredReusableCell(
                    using: TextCell.registration, for: indexPath, item: item)
            case .image:
                return collectionView.dequeueConfiguredReusableCell(
                    using: ImageCell.registration, for: indexPath, item: item)
            }
        }
    }
}

ListCollectionView(
    snapshot: viewModel.snapshot,
    cellProvider: MyCellProvider.makeProvider(),
    cacheKeyProvider: { $0.cacheKey },
    scrollTarget: scrollTarget
)
```

Switch on **`item`**, not `indexPath.section`, unless section also determines cell type.

### Pattern C — Multiple sections

**Supported at data layer.** Component is generic over `Section: Hashable` and accepts full `NSDiffableDataSourceSnapshot<Section, Item>`.

```swift
enum FeedSection: Hashable {
    case pinned
    case timeline
    case suggestions
}

var snapshot = NSDiffableDataSourceSnapshot<FeedSection, FeedItem>()
snapshot.appendSections([.pinned, .timeline, .suggestions])
snapshot.appendItems(pinned, toSection: .pinned)
snapshot.appendItems(posts, toSection: .timeline)
snapshot.appendItems(suggestions, toSection: .suggestions)
```

| Feature | Status |
|---------|--------|
| Multiple sections in snapshot | ✅ Supported |
| Same layout for all sections | ✅ Default layout works |
| Different layout per section | ✅ Via custom `layoutProvider` |
| Different cell per section | ✅ Switch on `indexPath.section` in `cellProvider` |
| Section header / footer | ❌ Not supported yet |
| Supplementary views | ❌ Not supported yet |

**Per-section layout example:**

```swift
ListCollectionView(
    snapshot: viewModel.snapshot,
    layoutProvider: { _ in
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            switch sectionIndex {
            case 0: return pinnedSectionLayout()   // horizontal, fixed height
            default: return timelineSectionLayout() // vertical, estimated height
            }
        }
    },
    cellProvider: MyCellProvider.makeProvider(),
    cacheKeyProvider: { $0.cacheKey }
)
```

### Scroll-to-item API

```swift
@State private var scrollTarget: ListScrollTarget<MyItem>?

// After data update:
scrollTarget = .bottom(lastItem)   // chat: scroll to newest
scrollTarget = .top(firstItem)
scrollTarget = .center(middleItem)

ListCollectionView(..., scrollTarget: scrollTarget)
```

- Scroll is deferred until snapshot `apply` completes (no race with diffing)
- Each `ListScrollTarget` has a unique `id: UUID` — re-assign to trigger re-scroll to same item
- Scroll resolves item by identifier, not section index

### Callbacks

```swift
ListCollectionViewCallbacks(
    didSelect: { item in },                        // tap
    willDisplay: { item, indexPath in },          // indexPath.section available here
    didEndDisplaying: { item, indexPath in },
    prefetch: { items in },                       // batch prefetch
    cancelPrefetch: { items in },
    scrollViewDidScroll: { scrollView in }
)
```

`didSelect` / `prefetch` receive `Item` only. Use `willDisplay` if you need `indexPath.section`.

### Custom layout

- Default: full-width vertical list, estimated height 52pt
- Override via `layoutProvider: (UICollectionView) -> UICollectionViewLayout`
- `layoutProvider` receives the **real** `UICollectionView` instance (not a dummy)
- For chat-style inverted list or sticky headers, supply a custom `UICollectionViewCompositionalLayout`

### Navigator integration

```swift
// Navigator.swift
enum Scene {
    case myList
}

// in getViewController:
case .myList:
    return MyListViewController()

// MyListViewController.swift
final class MyListViewController: UIHostingController<MyListView> {
    init() { super.init(rootView: MyListView()) }
    required init?(coder: NSCoder) { super.init(coder: coder, rootView: MyListView()) }
}

// Navigate:
Application.shared.navigator.show(segue: .myList, sender: self, transition: .push)
```

### Xcode project registration

Every new Swift file must be added to `app.xcodeproj/project.pbxproj`:

1. `PBXFileReference` entry
2. `PBXBuildFile` entry
3. Add file ref to correct `PBXGroup`
4. Add build file to `PBXSourcesBuildPhase`

Copy an existing entry pattern (e.g. `ListCollectionView.swift` or `CommentListExample.swift`).

### Common pitfalls — DO NOT

| Mistake | Why it breaks |
|---------|---------------|
| `reloadData()` on the collection view | Defeats diffing, kills scroll position & performance |
| Cache keyed by `IndexPath` | Same content at new index re-measures unnecessarily |
| `cacheKey` only uses `id` | Layout changes (expand, edit text) show stale height |
| Plain `UICollectionViewCell` for dynamic height | Size cache not attached |
| Scroll in `onChange` before snapshot propagates | Race condition — use `scrollTarget` instead |
| Same `Item` in two sections | Violates DiffableDataSource uniqueness |
| Forget `pbxproj` | Build fails with "cannot find type" |

### Demo screens (manual QA)

From Home screen buttons:

- **Comments** → `CommentListExampleView` — single cell, tap to expand, dynamic height
- **Chat** → `ChatListExampleView` — text/sticker/image cells, scroll-to-top/bottom

### Extending the component (future work)

If a task requires features not yet in the API, implement in `ListCollectionView.swift`:

1. **Section headers/footers** — add `supplementaryViewProvider` to coordinator + registration API
2. **Section-aware callbacks** — extend `ListCollectionViewCallbacks` with `Section` parameter
3. **Section-based layout helper** — `layoutProvider` that maps `Section` identifier instead of raw index

Do not duplicate the bridge in screen files — keep UIKit plumbing centralized in the component.