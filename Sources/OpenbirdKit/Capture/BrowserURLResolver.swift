import AppKit
import Foundation

public struct BrowserURLResolver: Sendable {
    private static let cacheLifetime: TimeInterval = 15
    @MainActor private static var cache: [String: CacheEntry] = [:]

    public init() {}

    @MainActor
    public func currentURL(for bundleID: String, windowTitle: String) -> String? {
        guard isPrivateWindow(title: windowTitle) == false else { return nil }

        let cacheKey = "\(bundleID)|\(windowTitle)"
        let now = Date()
        if let cached = Self.cache[cacheKey],
           now.timeIntervalSince(cached.resolvedAt) <= Self.cacheLifetime {
            return cached.url
        }

        let resolvedURL: String?
        switch bundleID {
        case "com.apple.Safari":
            resolvedURL = runAppleScript("""
            tell application "Safari"
                if (count of windows) is 0 then return ""
                return URL of current tab of front window
            end tell
            """)
        case "com.google.Chrome", "company.thebrowser.Browser", "com.brave.Browser", "com.microsoft.edgemac":
            resolvedURL = runAppleScript("""
            tell application id "\(bundleID)"
                if (count of windows) is 0 then return ""
                return URL of active tab of front window
            end tell
            """)
        default:
            resolvedURL = nil
        }

        Self.cache = Self.cache.filter { now.timeIntervalSince($0.value.resolvedAt) <= Self.cacheLifetime }
        Self.cache[cacheKey] = CacheEntry(url: resolvedURL, resolvedAt: now)
        return resolvedURL
    }

    private func isPrivateWindow(title: String) -> Bool {
        let lowered = title.lowercased()
        return lowered.contains("private") || lowered.contains("incognito")
    }

    private func runAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil else { return nil }
        let value = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == true ? nil : value
    }
}

private struct CacheEntry {
    let url: String?
    let resolvedAt: Date
}
