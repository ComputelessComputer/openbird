import Foundation

public struct InstalledApplication: Identifiable, Hashable, Sendable {
    public let bundleID: String
    public let name: String
    public let bundlePath: String

    public var id: String { bundleID }

    public init(bundleID: String, name: String, bundlePath: String) {
        self.bundleID = bundleID
        self.name = name
        self.bundlePath = bundlePath
    }
}
