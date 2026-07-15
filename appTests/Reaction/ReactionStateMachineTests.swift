import XCTest
@testable import app

// MARK: - Helpers

private extension ReactionSnapshot {
    static func idle(
        server: OAReaction,
        display: OAReaction? = nil
    ) -> ReactionSnapshot {
        ReactionSnapshot(
            server: server,
            display: display ?? server,
            phase: .idle
        )
    }
}

private func apply(
    _ snapshot: ReactionSnapshot,
    _ events: [ReactionEvent]
) -> ReactionTransition {
    events.reduce(ReactionTransition(snapshot: snapshot, effects: [])) { partial, event in
        ReactionStateMachine.reduce(snapshot: partial.snapshot, event: event)
    }
}

private func effects(from events: [ReactionEvent], startingAt snapshot: ReactionSnapshot) -> [ReactionEffect] {
    apply(snapshot, events).effects
}

// MARK: - Tests

final class ReactionStateMachineTests: XCTestCase {

    // MARK: Case 1

    func testCase1_singleTap_emitsHeartAfterDebounce() {
        let start = ReactionStateMachine.initial(server: .none)

        let afterTap = ReactionStateMachine.reduce(snapshot: start, event: .tap)
        XCTAssertEqual(afterTap.snapshot.display, .heart)
        XCTAssertEqual(afterTap.snapshot.phase, .debouncing)
        XCTAssertEqual(afterTap.effects, [.updateDisplay(.heart)])

        let afterDebounce = ReactionStateMachine.reduce(
            snapshot: afterTap.snapshot,
            event: .debounceElapsed
        )
        XCTAssertEqual(afterDebounce.snapshot.phase, .syncing(commit: .heart))
        XCTAssertEqual(afterDebounce.effects, [.commit(.heart)])
    }

    // MARK: Case 2

    func testCase2_doubleTap_noCommitAfterDebounce() {
        let start = ReactionStateMachine.initial(server: .none)

        let afterTaps = apply(start, [.tap, .tap])
        XCTAssertEqual(afterTaps.snapshot.display, .none)
        XCTAssertEqual(afterTaps.snapshot.phase, .debouncing)

        let afterDebounce = ReactionStateMachine.reduce(
            snapshot: afterTaps.snapshot,
            event: .debounceElapsed
        )
        XCTAssertEqual(afterDebounce.snapshot.phase, .idle)
        XCTAssertTrue(afterDebounce.effects.isEmpty)
    }

    // MARK: Case 3

    func testCase3_syncingTapsThenSuccess_emitsFollowUpCommit() {
        let start = ReactionStateMachine.initial(server: .none)

        let afterDebounce = apply(start, [.tap, .debounceElapsed])
        XCTAssertEqual(afterDebounce.snapshot.phase, .syncing(commit: .heart))
        XCTAssertEqual(afterDebounce.effects, [.updateDisplay(.heart), .commit(.heart)])

        let afterSyncTaps = apply(afterDebounce.snapshot, [.tap, .tap, .tap])
        XCTAssertEqual(afterSyncTaps.snapshot.display, .none)
        XCTAssertEqual(afterSyncTaps.snapshot.phase, .syncing(commit: .heart))
        XCTAssertEqual(afterSyncTaps.effects, [
            .updateDisplay(.none),
            .updateDisplay(.heart),
            .updateDisplay(.none)
        ])

        let afterSuccess = ReactionStateMachine.reduce(
            snapshot: afterSyncTaps.snapshot,
            event: .apiSucceeded
        )
        XCTAssertEqual(afterSuccess.snapshot.server, .heart)
        XCTAssertEqual(afterSuccess.snapshot.display, .none)
        XCTAssertEqual(afterSuccess.snapshot.phase, .syncing(commit: .none))
        XCTAssertEqual(afterSuccess.effects, [.commit(.none)])
    }

    // MARK: Case 4

    func testCase4_apiFailure_rollsBackDisplay() {
        let syncing = apply(
            ReactionStateMachine.initial(server: .none),
            [.tap, .debounceElapsed]
        ).snapshot

        let afterFailure = ReactionStateMachine.reduce(snapshot: syncing, event: .apiFailed)
        XCTAssertEqual(afterFailure.snapshot, .idle(server: .none))
        XCTAssertEqual(afterFailure.effects, [.updateDisplay(.none)])
    }

    // MARK: Case 5

    func testCase5_externalUpdateMatchesDisplay_noExtraCommit() {
        let debouncing = apply(
            ReactionStateMachine.initial(server: .none),
            [.tap]
        ).snapshot

        let afterRender = ReactionStateMachine.reduce(
            snapshot: debouncing,
            event: .serverRendered(.heart)
        )
        XCTAssertEqual(afterRender.snapshot, .idle(server: .heart, display: .heart))
        XCTAssertEqual(afterRender.effects, [.updateDisplay(.heart)])

        let afterDebounce = ReactionStateMachine.reduce(
            snapshot: afterRender.snapshot,
            event: .debounceElapsed
        )
        XCTAssertTrue(afterDebounce.effects.isEmpty)
        XCTAssertEqual(afterDebounce.snapshot.phase, .idle)
    }

    // MARK: Case 6

    func testCase6_externalUpdateResetsDisplay() {
        let debouncing = apply(
            ReactionStateMachine.initial(server: .none),
            [.tap]
        ).snapshot

        let afterRender = ReactionStateMachine.reduce(
            snapshot: debouncing,
            event: .serverRendered(.none)
        )
        XCTAssertEqual(afterRender.snapshot, .idle(server: .none))
        XCTAssertEqual(afterRender.effects, [.updateDisplay(.none)])
    }

    // MARK: Case 7 (state machine level)

    func testCase7_spamTaps_stateRemainsConsistent() {
        var snapshot = ReactionStateMachine.initial(server: .none)
        var commitCount = 0

        for _ in 0..<100 {
            let transition = ReactionStateMachine.reduce(snapshot: snapshot, event: .tap)
            snapshot = transition.snapshot
        }

        XCTAssertEqual(snapshot.phase, .debouncing)

        let final = ReactionStateMachine.reduce(snapshot: snapshot, event: .debounceElapsed)
        if case .commit = final.effects.first {
            commitCount += 1
        }

        XCTAssertLessThanOrEqual(commitCount, 1)
        XCTAssertTrue(
            final.snapshot.phase == .idle || final.snapshot.phase == .syncing(commit: final.snapshot.display)
        )
    }

    // MARK: Transition matrix

    func testTapFromIdle_entersDebouncing() {
        let result = ReactionStateMachine.reduce(
            snapshot: .idle(server: .none),
            event: .tap
        )
        XCTAssertEqual(result.snapshot.phase, .debouncing)
        XCTAssertEqual(result.snapshot.display, .heart)
    }

    func testTapDuringSyncing_onlyUpdatesDisplay() {
        let syncing = ReactionSnapshot(
            server: .none,
            display: .heart,
            phase: .syncing(commit: .heart)
        )

        let result = ReactionStateMachine.reduce(snapshot: syncing, event: .tap)
        XCTAssertEqual(result.snapshot.phase, .syncing(commit: .heart))
        XCTAssertEqual(result.snapshot.display, .none)
        XCTAssertEqual(result.effects, [.updateDisplay(.none)])
    }

    func testDebounceDuringSyncing_isIgnored() {
        let syncing = ReactionSnapshot(
            server: .none,
            display: .heart,
            phase: .syncing(commit: .heart)
        )

        let result = ReactionStateMachine.reduce(snapshot: syncing, event: .debounceElapsed)
        XCTAssertEqual(result.snapshot, syncing)
        XCTAssertTrue(result.effects.isEmpty)
    }

    func testAPISuccessWhenAligned_returnsToIdle() {
        let syncing = ReactionSnapshot(
            server: .none,
            display: .heart,
            phase: .syncing(commit: .heart)
        )

        let result = ReactionStateMachine.reduce(snapshot: syncing, event: .apiSucceeded)
        XCTAssertEqual(result.snapshot, .idle(server: .heart, display: .heart))
        XCTAssertTrue(result.effects.isEmpty)
    }

    func testAPIFailureWhenDisplayAlreadyMatchesServer_noDisplayEffect() {
        let syncing = ReactionSnapshot(
            server: .none,
            display: .none,
            phase: .syncing(commit: .heart)
        )

        let afterTap = ReactionStateMachine.reduce(snapshot: syncing, event: .tap)
        XCTAssertEqual(afterTap.snapshot.display, .heart)

        let afterFailure = ReactionStateMachine.reduce(snapshot: afterTap.snapshot, event: .apiFailed)
        XCTAssertEqual(afterFailure.snapshot, .idle(server: .none))
        XCTAssertEqual(afterFailure.effects, [.updateDisplay(.none)])
    }

    func testServerRenderedDuringSyncing_keepsSyncingPhase() {
        let syncing = ReactionSnapshot(
            server: .none,
            display: .heart,
            phase: .syncing(commit: .heart)
        )

        let result = ReactionStateMachine.reduce(
            snapshot: syncing,
            event: .serverRendered(.none)
        )
        XCTAssertEqual(result.snapshot.server, .none)
        XCTAssertEqual(result.snapshot.display, .none)
        XCTAssertEqual(result.snapshot.phase, .syncing(commit: .heart))
    }
}
