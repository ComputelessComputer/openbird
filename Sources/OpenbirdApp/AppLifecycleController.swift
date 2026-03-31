import AppKit
import OSLog
import OpenbirdKit

@MainActor
final class AppLifecycleController: NSObject, NSApplicationDelegate {
    private static let terminationPreparationTimeout: Duration = .seconds(5)

    private let logger = OpenbirdLog.lifecycle
    private var openMainWindow: () -> Void = {}
    private var prepareForTermination: @MainActor @Sendable () async -> Void = {}
    private var allowsFullTermination = false
    private var isHandlingTermination = false

    func configure(
        openMainWindow: @escaping () -> Void,
        prepareForTermination: @escaping @MainActor @Sendable () async -> Void
    ) {
        self.openMainWindow = openMainWindow
        self.prepareForTermination = prepareForTermination
    }

    func openApp() {
        logger.notice("Opening main window")
        openMainWindow()
    }

    func closeAllWindows() {
        logger.notice("Closing all windows")
        for window in NSApp.windows where window.styleMask.contains(.closable) {
            window.performClose(nil)
        }
    }

    func quitCompletely() {
        logger.notice("Quitting Openbird completely")
        allowsFullTermination = true
        NSApp.terminate(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard allowsFullTermination else {
            logger.notice("Intercepted termination request and closed windows instead")
            closeAllWindows()
            return .terminateCancel
        }

        guard isHandlingTermination == false else {
            logger.debug("Termination already in progress")
            return .terminateLater
        }

        isHandlingTermination = true
        logger.notice("Preparing for application termination")
        Task { [weak self] in
            guard let self else { return }
            let didFinishPreparation = await Self.waitForTerminationPreparation(
                timeout: Self.terminationPreparationTimeout,
                operation: prepareForTermination
            )
            await MainActor.run {
                isHandlingTermination = false
                if didFinishPreparation {
                    logger.notice("Application termination cleanup finished")
                } else {
                    logger.error("Application termination cleanup timed out; quitting anyway")
                }
                sender.reply(toApplicationShouldTerminate: true)
            }
        }
        return .terminateLater
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard flag == false else {
            return false
        }

        logger.notice("Reopening application without visible windows")
        openApp()
        return true
    }

    static func waitForTerminationPreparation(
        timeout: Duration,
        operation: @escaping @MainActor @Sendable () async -> Void
    ) async -> Bool {
        let results = AsyncStream<Bool> { continuation in
            let preparationTask = Task { @MainActor in
                await operation()
                continuation.yield(true)
                continuation.finish()
            }
            let timeoutTask = Task {
                try? await Task.sleep(for: timeout)
                preparationTask.cancel()
                continuation.yield(false)
                continuation.finish()
            }

            continuation.onTermination = { _ in
                preparationTask.cancel()
                timeoutTask.cancel()
            }
        }

        for await result in results {
            return result
        }

        return true
    }
}
