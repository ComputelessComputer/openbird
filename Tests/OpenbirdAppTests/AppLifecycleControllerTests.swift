import Foundation
import Testing
@testable import OpenbirdApp

@MainActor
struct AppLifecycleControllerTests {
    @Test func terminationPreparationCompletesBeforeTimeout() async {
        let completed = await AppLifecycleController.waitForTerminationPreparation(
            timeout: .milliseconds(100)
        ) {
            let deadline = ContinuousClock.now.advanced(by: .milliseconds(20))
            while ContinuousClock.now < deadline {
                await Task.yield()
            }
        }

        #expect(completed)
    }

    @Test func terminationPreparationTimesOut() async {
        let completed = await AppLifecycleController.waitForTerminationPreparation(
            timeout: .milliseconds(20)
        ) {
            let deadline = ContinuousClock.now.advanced(by: .milliseconds(100))
            while ContinuousClock.now < deadline {
                await Task.yield()
            }
        }

        #expect(completed == false)
    }
}
