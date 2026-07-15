import Combine
import XCTest
@testable import app

final class ReactionControllerTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeController(
        server: OAReaction = .none,
        debounceInterval: TimeInterval = 0.05
    ) -> ReactionController {
        ReactionController(
            initialServerReaction: server,
            configuration: ReactionControllerConfiguration(
                debounceInterval: debounceInterval,
                debounceScheduler: DispatchQueue(label: "test.reaction.debounce"),
                deliveryQueue: DispatchQueue(label: "test.reaction.delivery")
            )
        )
    }

    private func waitDebounce(_ interval: TimeInterval = 0.12) {
        let exp = expectation(description: "debounce")
        DispatchQueue.global().asyncAfter(deadline: .now() + interval) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: interval + 0.5)
    }

    // MARK: Case 1

    func testCase1_controller_emitsHeartAfterDebounce() {
        let controller = makeController()
        var displayValues: [OAReaction] = []
        var commits: [OAReaction] = []

        controller.displayPublisher.sink { displayValues.append($0) }.store(in: &cancellables)
        controller.commitPublisher.sink { commits.append($0) }.store(in: &cancellables)

        controller.acceptTap()
        XCTAssertEqual(controller.currentDisplay, .heart)

        waitDebounce()

        XCTAssertEqual(commits, [.heart])
        XCTAssertEqual(displayValues.last, .heart)
    }

    // MARK: Case 2

    func testCase2_controller_doubleTap_noCommit() {
        let controller = makeController()
        var commits: [OAReaction] = []

        controller.commitPublisher.sink { commits.append($0) }.store(in: &cancellables)

        controller.acceptTap()
        controller.acceptTap()
        waitDebounce()

        XCTAssertTrue(commits.isEmpty)
        XCTAssertEqual(controller.currentDisplay, .none)
    }

    // MARK: Case 3

    func testCase3_controller_followUpCommitAfterSuccess() {
        let controller = makeController()
        var commits: [OAReaction] = []

        controller.commitPublisher.sink { commits.append($0) }.store(in: &cancellables)

        controller.acceptTap()
        waitDebounce()
        XCTAssertEqual(commits, [.heart])

        controller.acceptTap()
        controller.acceptTap()
        controller.acceptTap()
        XCTAssertEqual(controller.currentDisplay, .none)

        controller.apiSucceeded()

        XCTAssertEqual(commits, [.heart, .none])
        XCTAssertEqual(controller.currentServer, .heart)
        XCTAssertEqual(controller.currentDisplay, .none)
    }

    // MARK: Case 4

    func testCase4_controller_apiFailureRollsBackDisplay() {
        let controller = makeController()
        var displayValues: [OAReaction] = []

        controller.displayPublisher.sink { displayValues.append($0) }.store(in: &cancellables)

        controller.acceptTap()
        waitDebounce()
        controller.apiFailed()

        XCTAssertEqual(controller.currentDisplay, .none)
        XCTAssertEqual(displayValues.last, .none)
    }

    // MARK: Case 5

    func testCase5_controller_externalHeartUpdate_noExtraCommit() {
        let controller = makeController()
        var commits: [OAReaction] = []

        controller.commitPublisher.sink { commits.append($0) }.store(in: &cancellables)

        controller.acceptTap()
        controller.render(serverReaction: .heart)
        waitDebounce()

        XCTAssertTrue(commits.isEmpty)
        XCTAssertEqual(controller.currentDisplay, .heart)
        XCTAssertEqual(controller.currentServer, .heart)
    }

    // MARK: Case 6

    func testCase6_controller_externalNoneUpdate_resetsDisplay() {
        let controller = makeController()
        var displayValues: [OAReaction] = []

        controller.displayPublisher.sink { displayValues.append($0) }.store(in: &cancellables)

        controller.acceptTap()
        controller.render(serverReaction: .none)
        waitDebounce()

        XCTAssertEqual(controller.currentDisplay, .none)
        XCTAssertEqual(displayValues.last, .none)
    }

    // MARK: Case 7

    func testCase7_controller_spamTaps_noCrashAndSingleCommit() {
        let controller = makeController(debounceInterval: 0.02)
        var commits: [OAReaction] = []

        controller.commitPublisher.sink { commits.append($0) }.store(in: &cancellables)

        for _ in 0..<100 {
            controller.acceptTap()
        }

        waitDebounce(0.15)

        XCTAssertLessThanOrEqual(commits.count, 1)
        XCTAssertEqual(controller.currentServer, .none)
    }

    func testController_deinit_cancelsSubscriptions() {
        weak var weakController: ReactionController?
        autoreleasepool {
            let controller = makeController()
            weakController = controller
            controller.displayPublisher.sink { _ in }.store(in: &cancellables)
        }
        XCTAssertNil(weakController)
    }

    func testDisplayPublisher_removeDuplicates() {
        let controller = makeController()
        var emissionCount = 0

        controller.displayPublisher
            .sink { _ in emissionCount += 1 }
            .store(in: &cancellables)

        controller.render(serverReaction: .none)
        controller.render(serverReaction: .none)

        XCTAssertEqual(emissionCount, 1)
    }
}
