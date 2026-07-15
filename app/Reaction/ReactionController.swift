import Combine
import Foundation

// MARK: - Configuration

public struct ReactionControllerConfiguration: Sendable {
    public let debounceInterval: TimeInterval
    public let debounceScheduler: DispatchQueue
    public let deliveryQueue: DispatchQueue

    public init(
        debounceInterval: TimeInterval = 0.5,
        debounceScheduler: DispatchQueue = DispatchQueue(label: "com.reaction.debounce"),
        deliveryQueue: DispatchQueue = .main
    ) {
        self.debounceInterval = debounceInterval
        self.debounceScheduler = debounceScheduler
        self.deliveryQueue = deliveryQueue
    }
}

// MARK: - Controller

/// Headless reaction controller.
///
/// Owns optimistic UI state, debounce, rollback, and commit emission.
/// Does not import UIKit and has no knowledge of views or networking.
public final class ReactionController {

    // MARK: - Public API

    public var displayPublisher: AnyPublisher<OAReaction, Never> {
        displaySubject
            .removeDuplicates()
            .receive(on: configuration.deliveryQueue)
            .eraseToAnyPublisher()
    }

    public var commitPublisher: AnyPublisher<OAReaction, Never> {
        commitSubject
            .receive(on: configuration.deliveryQueue)
            .eraseToAnyPublisher()
    }

    public var currentDisplay: OAReaction {
        lock.withLock { snapshot.display }
    }

    public var currentServer: OAReaction {
        lock.withLock { snapshot.server }
    }

    // MARK: - Private State

    private let configuration: ReactionControllerConfiguration
    private let displaySubject: CurrentValueSubject<OAReaction, Never>
    private let commitSubject = PassthroughSubject<OAReaction, Never>()
    private let tapSubject = PassthroughSubject<Void, Never>()
    private let lock = NSLock()
    private var snapshot: ReactionSnapshot
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    public init(
        initialServerReaction: OAReaction = .none,
        configuration: ReactionControllerConfiguration = ReactionControllerConfiguration()
    ) {
        self.configuration = configuration
        let initialSnapshot = ReactionStateMachine.initial(server: initialServerReaction)
        self.snapshot = initialSnapshot
        self.displaySubject = CurrentValueSubject(initialSnapshot.display)
        bind()
    }

    deinit {
        cancellables.removeAll()
    }

    // MARK: - Input

    /// User tapped the like button. Toggles display immediately and schedules debounce.
    public func acceptTap() {
        tapSubject.send(())
    }

    /// External source updated server truth (store, websocket, parent view model, etc.).
    public func render(serverReaction: OAReaction) {
        dispatch(.serverRendered(serverReaction))
    }

    /// In-flight commit succeeded. Server is updated to the committed reaction.
    public func apiSucceeded() {
        dispatch(.apiSucceeded)
    }

    /// In-flight commit failed. Display rolls back to server automatically.
    public func apiFailed() {
        dispatch(.apiFailed)
    }

    // MARK: - Wiring

    private func bind() {
        tapSubject
            .sink { [weak self] in
                self?.dispatch(.tap)
            }
            .store(in: &cancellables)

        tapSubject
            .debounce(
                for: .seconds(configuration.debounceInterval),
                scheduler: configuration.debounceScheduler
            )
            .sink { [weak self] in
                self?.dispatch(.debounceElapsed)
            }
            .store(in: &cancellables)
    }

    // MARK: - Dispatch

    private func dispatch(_ event: ReactionEvent) {
        let transition: ReactionTransition = lock.withLock {
            let result = ReactionStateMachine.reduce(snapshot: snapshot, event: event)
            snapshot = result.snapshot
            return result
        }

        apply(effects: transition.effects)
    }

    private func apply(effects: [ReactionEffect]) {
        for effect in effects {
            switch effect {
            case .updateDisplay(let reaction):
                displaySubject.send(reaction)
            case .commit(let reaction):
                commitSubject.send(reaction)
            }
        }
    }
}

// MARK: - NSLock helper

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
