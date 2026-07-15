import Foundation

// MARK: - Snapshot

/// Immutable snapshot of reaction state at a point in time.
public struct ReactionSnapshot: Equatable, Sendable {
    public var server: OAReaction
    public var display: OAReaction
    public var phase: ReactionPhase

    public init(server: OAReaction, display: OAReaction, phase: ReactionPhase) {
        self.server = server
        self.display = display
        self.phase = phase
    }
}

// MARK: - Phase

/// High-level lifecycle phase. Replaces scattered boolean flags.
public enum ReactionPhase: Equatable, Sendable {
    /// No pending debounce and no in-flight commit.
    case idle

    /// User tapped recently; waiting for debounce window to settle.
    case debouncing

    /// A commit is in-flight toward the server.
    case syncing(commit: OAReaction)
}

// MARK: - Event

/// All inputs that can drive state transitions.
public enum ReactionEvent: Equatable, Sendable {
    case tap
    case debounceElapsed
    case apiSucceeded
    case apiFailed
    case serverRendered(OAReaction)
}

// MARK: - Effect

/// Side effects produced by a transition for the controller to execute.
public enum ReactionEffect: Equatable, Sendable {
    case updateDisplay(OAReaction)
    case commit(OAReaction)
}

// MARK: - Transition Result

public struct ReactionTransition: Equatable, Sendable {
    public let snapshot: ReactionSnapshot
    public let effects: [ReactionEffect]

    public init(snapshot: ReactionSnapshot, effects: [ReactionEffect]) {
        self.snapshot = snapshot
        self.effects = effects
    }
}

// MARK: - State Machine

/// Pure, headless state machine for like/unlike interaction.
///
/// The machine tracks three values:
/// - `server`: last known server truth (updated on `serverRendered` and successful API)
/// - `display`: optimistic UI value (updated immediately on tap)
/// - `phase`: whether we are debouncing taps or waiting for an API result
///
/// Commit events are emitted only when `display != server` after debounce,
/// on API success when display diverged during sync, and never when they already match.
public enum ReactionStateMachine {

    public static func initial(server: OAReaction = .none) -> ReactionSnapshot {
        ReactionSnapshot(server: server, display: server, phase: .idle)
    }

    public static func reduce(
        snapshot: ReactionSnapshot,
        event: ReactionEvent
    ) -> ReactionTransition {
        switch event {
        case .tap:
            return handleTap(snapshot: snapshot)
        case .debounceElapsed:
            return handleDebounceElapsed(snapshot: snapshot)
        case .apiSucceeded:
            return handleAPISucceeded(snapshot: snapshot)
        case .apiFailed:
            return handleAPIFailed(snapshot: snapshot)
        case .serverRendered(let reaction):
            return handleServerRendered(snapshot: snapshot, reaction: reaction)
        }
    }

    // MARK: - Handlers

    private static func handleTap(snapshot: ReactionSnapshot) -> ReactionTransition {
        var next = snapshot
        let newDisplay = snapshot.display.toggled
        next.display = newDisplay

        switch snapshot.phase {
        case .idle:
            next.phase = .debouncing
        case .debouncing, .syncing:
            break
        }

        return ReactionTransition(
            snapshot: next,
            effects: [.updateDisplay(newDisplay)]
        )
    }

    private static func handleDebounceElapsed(snapshot: ReactionSnapshot) -> ReactionTransition {
        switch snapshot.phase {
        case .idle, .syncing:
            return ReactionTransition(snapshot: snapshot, effects: [])

        case .debouncing:
            if snapshot.display == snapshot.server {
                var next = snapshot
                next.phase = .idle
                return ReactionTransition(snapshot: next, effects: [])
            }

            var next = snapshot
            next.phase = .syncing(commit: snapshot.display)
            return ReactionTransition(
                snapshot: next,
                effects: [.commit(snapshot.display)]
            )
        }
    }

    private static func handleAPISucceeded(snapshot: ReactionSnapshot) -> ReactionTransition {
        guard case .syncing(let commit) = snapshot.phase else {
            return ReactionTransition(snapshot: snapshot, effects: [])
        }

        var next = snapshot
        next.server = commit

        if next.display == commit {
            next.phase = .idle
            return ReactionTransition(snapshot: next, effects: [])
        }

        next.phase = .syncing(commit: next.display)
        return ReactionTransition(
            snapshot: next,
            effects: [.commit(next.display)]
        )
    }

    private static func handleAPIFailed(snapshot: ReactionSnapshot) -> ReactionTransition {
        guard case .syncing = snapshot.phase else {
            return ReactionTransition(snapshot: snapshot, effects: [])
        }

        var next = snapshot
        next.display = next.server
        next.phase = .idle

        let needsDisplayRollback = next.display != snapshot.display
        let effects: [ReactionEffect] = needsDisplayRollback
            ? [.updateDisplay(next.display)]
            : []

        return ReactionTransition(snapshot: next, effects: effects)
    }

    private static func handleServerRendered(
        snapshot: ReactionSnapshot,
        reaction: OAReaction
    ) -> ReactionTransition {
        var next = snapshot
        next.server = reaction
        next.display = reaction

        switch snapshot.phase {
        case .idle, .debouncing:
            next.phase = .idle
        case .syncing:
            // Keep syncing; the in-flight request will reconcile via apiSucceeded/apiFailed.
            break
        }

        let needsDisplayUpdate = reaction != snapshot.display
        let effects: [ReactionEffect] = needsDisplayUpdate
            ? [.updateDisplay(reaction)]
            : []

        return ReactionTransition(snapshot: next, effects: effects)
    }
}
