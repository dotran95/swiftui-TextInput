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