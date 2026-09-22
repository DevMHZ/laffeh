// Run from the repository root:
// swiftc -swift-version 5 -D SHARE_PAYLOAD_TEST \
//   'ios/Share Extension/ShareViewController.swift' \
//   test/native/share_payload_collector_test.swift -o /tmp/laffeh-share-tests
// /tmp/laffeh-share-tests
import Foundation

final class SharePayloadCollectorTests {
    private final class Expectation {
        var fulfilled = false
        func fulfill() { fulfilled = true }
    }

    private func expectation(description: String) -> Expectation { Expectation() }

    private func wait(for expectations: [Expectation], timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while expectations.contains(where: { !$0.fulfilled }) && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.005))
        }
        precondition(expectations.allSatisfy { $0.fulfilled }, "Timed out waiting for share payload")
    }

    private let url = SharedLocationPayload(text: "https://maps.app.goo.gl/example", isURL: true)
    private let caption = SharedLocationPayload(text: "Restaurant", isURL: false)

    func testLastIndexFinishingFirstDoesNotLoseURL() {
        let finished = expectation(description: "All attachments collected")
        var finishURL: ((SharedLocationPayload?) -> Void)?
        var handedOff = false
        SharedLocationCollector.collect([
            { finishURL = $0 },
            { $0(self.caption) }
        ]) { values in
            handedOff = true
            precondition(values == [self.url, self.caption])
            precondition(Thread.isMainThread)
            finished.fulfill()
        }
        DispatchQueue.main.async {
            precondition(!handedOff)
            finishURL?(self.url)
        }
        wait(for: [finished], timeout: 2)
    }

    func testConcurrentCallbacksKeepInputOrder() {
        let finished = expectation(description: "Concurrent providers collected")
        let expected = (0..<24).map { SharedLocationPayload(text: "Place \($0)", isURL: false) }
        var callbacks = [(SharedLocationPayload?) -> Void]()
        let loaders: [SharedLocationCollector.Loader] = expected.map { _ in
            { callbacks.append($0) }
        }
        SharedLocationCollector.collect(loaders) { values in
            precondition(values == expected)
            finished.fulfill()
        }
        for index in expected.indices.reversed() {
            let complete = callbacks[index]
            let value = expected[index]
            DispatchQueue.global().async { complete(value) }
        }
        wait(for: [finished], timeout: 2)
    }

    func testEmptyAndDuplicateRepresentationsAreRemoved() {
        let finished = expectation(description: "Unique content collected")
        SharedLocationCollector.collect([
            { $0(nil) },
            { $0(SharedLocationPayload(text: " \n", isURL: false)) },
            { $0(self.url) },
            { $0(SharedLocationPayload(text: " \(self.url.text)\n", isURL: false)) },
            { $0(self.caption) }
        ]) { values in
            precondition(values == [self.url, self.caption])
            finished.fulfill()
        }
        wait(for: [finished], timeout: 2)
    }

    func testNoProvidersCompletesWithEmptyPayload() {
        let finished = expectation(description: "Empty share completed")
        SharedLocationCollector.collect([]) { values in
            precondition(values.isEmpty)
            finished.fulfill()
        }
        wait(for: [finished], timeout: 2)
    }

    func testURLRepresentationWinsOverCaption() {
        var triedCaption = false
        var result: SharedLocationPayload?
        SharedLocationCollector.preferred([
            { $0(self.url) },
            { triedCaption = true; $0(self.caption) }
        ]) { result = $0 }
        precondition(result == url)
        precondition(!triedCaption)
    }

    func testFailedOrEmptyURLFallsBackToText() {
        var result: SharedLocationPayload?
        SharedLocationCollector.preferred([
            { $0(nil) },
            { $0(SharedLocationPayload(text: " ", isURL: true)) },
            { $0(self.caption) }
        ]) { result = $0 }
        precondition(result == caption)
    }

    func testFailedProviderCompletesWithNil() {
        var completed = false
        SharedLocationCollector.preferred([{ $0(nil) }]) { value in
            precondition(value == nil)
            completed = true
        }
        precondition(completed)
    }
}

@main
enum SharePayloadTestRunner {
    static func main() {
        let tests = SharePayloadCollectorTests()
        tests.testLastIndexFinishingFirstDoesNotLoseURL()
        tests.testConcurrentCallbacksKeepInputOrder()
        tests.testEmptyAndDuplicateRepresentationsAreRemoved()
        tests.testNoProvidersCompletesWithEmptyPayload()
        tests.testURLRepresentationWinsOverCaption()
        tests.testFailedOrEmptyURLFallsBackToText()
        tests.testFailedProviderCompletesWithNil()
        print("7 native share-payload regression tests passed")
    }
}
