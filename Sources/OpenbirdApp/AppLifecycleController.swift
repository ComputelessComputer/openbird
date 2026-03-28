import AppKit

@MainActor
final class AppLifecycleController: NSObject, NSApplicationDelegate {
    private var openMainWindow: () -> Void = {}
    private var allowsFullTermination = false

    func configure(openMainWindow: @escaping () -> Void) {
        self.openMainWindow = openMainWindow
    }

    func openApp() {
        openMainWindow()
    }

    func closeAllWindows() {
        for window in NSApp.windows where window.styleMask.contains(.closable) {
            window.performClose(nil)
        }
    }

    func quitCompletely() {
        allowsFullTermination = true
        NSApp.terminate(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard allowsFullTermination else {
            closeAllWindows()
            return .terminateCancel
        }

        return .terminateNow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard flag == false else {
            return false
        }

        openApp()
        return true
    }
}
