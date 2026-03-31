import ApplicationServices
import AppKit
import Foundation

struct FrontmostApplicationContext: Sendable {
    let processIdentifier: pid_t
    let bundleID: String
    let appName: String

    @MainActor
    static func current() -> FrontmostApplicationContext? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.isHidden == false,
              let bundleID = application.bundleIdentifier
        else {
            return nil
        }

        return FrontmostApplicationContext(
            processIdentifier: application.processIdentifier,
            bundleID: bundleID,
            appName: application.localizedName ?? bundleID
        )
    }
}

public struct AccessibilitySnapshotter: Sendable {
    private let snapshotSanitizer = SnapshotSanitizer()
    private let kakaoTalkBundleID = "com.kakao.KakaoTalkMac"

    public init() {}

    func snapshotFrontmostWindow(
        for application: FrontmostApplicationContext,
        includeVisibleText: Bool = true
    ) -> WindowSnapshot? {
        if shouldUseMinimalSnapshot(for: application) {
            let snapshot = snapshotSanitizer.sanitize(minimalSnapshot(for: application))
            return snapshotSanitizer.shouldDiscard(snapshot) ? nil : snapshot
        }

        let axApplication = AXUIElementCreateApplication(application.processIdentifier)
        guard let focusedWindow = copyElementAttribute(axApplication, attribute: kAXFocusedWindowAttribute)
                ?? copyElementAttribute(axApplication, attribute: kAXMainWindowAttribute)
        else {
            let snapshot = snapshotSanitizer.sanitize(minimalSnapshot(for: application))
            return snapshotSanitizer.shouldDiscard(snapshot) ? nil : snapshot
        }

        if boolAttribute(kAXMinimizedAttribute, on: focusedWindow) == true {
            return nil
        }

        let windowTitle = stringAttribute(kAXTitleAttribute, on: focusedWindow)
            ?? application.appName
        let url = stringAttribute("AXURL", on: focusedWindow)
        let visibleText: String
        if includeVisibleText {
            if application.bundleID == kakaoTalkBundleID {
                visibleText = collectKakaoTalkVisibleText(from: focusedWindow, application: axApplication)
            } else {
                let windowText = collectVisibleText(from: focusedWindow, depth: 0, remainingNodes: 220, remainingCharacters: 4000)
                let focusedElementText = copyElementAttribute(axApplication, attribute: kAXFocusedUIElementAttribute)
                    .map { collectVisibleText(from: $0, depth: 0, remainingNodes: 60, remainingCharacters: 1200) }
                    ?? ""
                visibleText = mergeTextFragments([windowText, focusedElementText])
            }
        } else {
            visibleText = ""
        }

        let snapshot = WindowSnapshot(
            bundleId: application.bundleID,
            appName: application.appName,
            windowTitle: windowTitle,
            url: url,
            visibleText: visibleText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
            source: "accessibility"
        )
        let sanitized = snapshotSanitizer.sanitize(snapshot)
        return snapshotSanitizer.shouldDiscard(sanitized) ? nil : sanitized
    }

    private func minimalSnapshot(for application: FrontmostApplicationContext) -> WindowSnapshot {
        WindowSnapshot(
            bundleId: application.bundleID,
            appName: application.appName,
            windowTitle: application.appName,
            url: nil,
            visibleText: "",
            source: "workspace"
        )
    }

    private func shouldUseMinimalSnapshot(for application: FrontmostApplicationContext) -> Bool {
        if application.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return true
        }

        guard let currentBundleID = Bundle.main.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              currentBundleID.isEmpty == false
        else {
            return false
        }

        return currentBundleID.caseInsensitiveCompare(application.bundleID) == .orderedSame
    }

    private func collectVisibleText(
        from element: AXUIElement,
        depth: Int,
        remainingNodes: Int,
        remainingCharacters: Int
    ) -> String {
        guard depth < 9, remainingNodes > 0, remainingCharacters > 0 else { return "" }

        let role = stringAttribute(kAXRoleAttribute, on: element) ?? ""
        if role.localizedCaseInsensitiveContains("secure") {
            return ""
        }

        var pieces: [String] = []
        if shouldCollectText(for: role) {
            let candidateAttributes = [
                kAXValueAttribute,
                kAXDescriptionAttribute,
                kAXTitleAttribute,
                kAXSelectedTextAttribute,
            ]

            for attribute in candidateAttributes {
                guard let text = stringAttribute(attribute, on: element)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      text.isEmpty == false,
                      text.count < 400
                else { continue }
                pieces.append(text)
            }
        }

        let children = prioritizedChildren(for: element)
        let childCount = max(children.count, 1)
        let preferredChildCount = min(12, childCount)
        let childBudget = max(4, remainingNodes / preferredChildCount)
        let charBudget = max(160, remainingCharacters / preferredChildCount)
        for child in children.prefix(min(preferredChildCount, remainingNodes)) {
            let childText = collectVisibleText(
                from: child,
                depth: depth + 1,
                remainingNodes: childBudget,
                remainingCharacters: charBudget
            )
            if childText.isEmpty == false {
                pieces.append(childText)
            }
        }

        let merged = pieces
            .joined(separator: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .removingDuplicates()
            .joined(separator: "\n")

        if merged.count <= remainingCharacters {
            return merged
        }
        return String(merged.prefix(remainingCharacters))
    }

    private func collectKakaoTalkVisibleText(from focusedWindow: AXUIElement, application: AXUIElement) -> String {
        let windowFrame = frame(of: focusedWindow)
        let windowFragments = collectTextFragments(
            from: focusedWindow,
            depth: 0,
            remainingNodes: 220,
            remainingCharacters: 4000
        )
        let focusedFragments = copyElementAttribute(application, attribute: kAXFocusedUIElementAttribute)
            .map {
                collectTextFragments(
                    from: $0,
                    depth: 0,
                    remainingNodes: 60,
                    remainingCharacters: 1200
                )
            } ?? []

        return mergeKakaoTalkFragments(windowFragments + focusedFragments, windowFrame: windowFrame)
    }

    private func collectTextFragments(
        from element: AXUIElement,
        depth: Int,
        remainingNodes: Int,
        remainingCharacters: Int
    ) -> [TextFragment] {
        guard depth < 9, remainingNodes > 0, remainingCharacters > 0 else { return [] }

        let role = stringAttribute(kAXRoleAttribute, on: element) ?? ""
        if role.localizedCaseInsensitiveContains("secure") {
            return []
        }

        var fragments: [TextFragment] = []
        let elementFrame = frame(of: element)
        if shouldCollectText(for: role) {
            let candidateAttributes = [
                kAXValueAttribute,
                kAXDescriptionAttribute,
                kAXTitleAttribute,
                kAXSelectedTextAttribute,
            ]

            for attribute in candidateAttributes {
                guard let text = stringAttribute(attribute, on: element)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      text.isEmpty == false,
                      text.count < 400
                else { continue }
                fragments.append(
                    TextFragment(
                        text: text,
                        frame: elementFrame
                    )
                )
            }
        }

        let children = prioritizedChildren(for: element)
        let childCount = max(children.count, 1)
        let preferredChildCount = min(12, childCount)
        let childBudget = max(4, remainingNodes / preferredChildCount)
        let charBudget = max(160, remainingCharacters / preferredChildCount)
        for child in children.prefix(min(preferredChildCount, remainingNodes)) {
            fragments.append(
                contentsOf: collectTextFragments(
                    from: child,
                    depth: depth + 1,
                    remainingNodes: childBudget,
                    remainingCharacters: charBudget
                )
            )
        }

        return fragments
    }

    private func mergeTextFragments(_ fragments: [String]) -> String {
        fragments
            .joined(separator: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .removingDuplicates()
            .joined(separator: "\n")
    }

    private func mergeKakaoTalkFragments(_ fragments: [TextFragment], windowFrame: CGRect?) -> String {
        fragments
            .map { fragment in
                AnnotatedTextLine(
                    text: fragment.text,
                    speaker: kakaoTalkSpeaker(for: fragment.frame, in: windowFrame),
                    frame: fragment.frame
                )
            }
            .sorted()
            .filter { $0.text.isEmpty == false }
            .deduplicatedByNormalizedText()
            .map(\.displayText)
            .joined(separator: "\n")
    }

    private func kakaoTalkSpeaker(for frame: CGRect?, in windowFrame: CGRect?) -> KakaoTalkSpeaker {
        guard let frame, let windowFrame, windowFrame.width > 0 else {
            return .unknown
        }

        let leadingInset = frame.minX - windowFrame.minX
        let trailingInset = windowFrame.maxX - frame.maxX

        if frame.width < 24 {
            return .unknown
        }

        if trailingInset < windowFrame.width * 0.16 && leadingInset > windowFrame.width * 0.42 {
            return .me
        }

        if leadingInset < windowFrame.width * 0.22 && trailingInset > windowFrame.width * 0.26 {
            return .them
        }

        return .unknown
    }

    private func copyElementAttribute(_ element: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func copyChildren(for element: AXUIElement) -> [AXUIElement] {
        let attributes = [kAXVisibleChildrenAttribute, kAXContentsAttribute, kAXChildrenAttribute]
        for attribute in attributes {
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
            guard result == .success,
                  let array = value as? [Any]
            else {
                continue
            }
            let elements: [AXUIElement] = array.compactMap { item in
                let object = item as AnyObject
                guard CFGetTypeID(object) == AXUIElementGetTypeID() else { return nil }
                return unsafeDowncast(object, to: AXUIElement.self)
            }
            if elements.isEmpty == false {
                return elements
            }
        }
        return []
    }

    private func prioritizedChildren(for element: AXUIElement) -> [AXUIElement] {
        copyChildren(for: element)
            .enumerated()
            .map { index, child in
                let role = stringAttribute(kAXRoleAttribute, on: child) ?? ""
                return PrioritizedChild(
                    element: child,
                    priority: childPriority(for: role),
                    order: index
                )
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                return lhs.order < rhs.order
            }
            .map(\.element)
    }

    private func stringAttribute(_ attribute: String, on element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        if let string = value as? String {
            return string
        }
        return nil
    }

    private func boolAttribute(_ attribute: String, on element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? Bool
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard let origin = pointAttribute(kAXPositionAttribute, on: element),
              let size = sizeAttribute(kAXSizeAttribute, on: element)
        else {
            return nil
        }

        return CGRect(origin: origin, size: size)
    }

    private func pointAttribute(_ attribute: String, on element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success,
              let axValue = value,
              AXValueGetType(axValue as! AXValue) == .cgPoint
        else {
            return nil
        }

        var point = CGPoint.zero
        guard AXValueGetValue(axValue as! AXValue, .cgPoint, &point) else {
            return nil
        }
        return point
    }

    private func sizeAttribute(_ attribute: String, on element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success,
              let axValue = value,
              AXValueGetType(axValue as! AXValue) == .cgSize
        else {
            return nil
        }

        var size = CGSize.zero
        guard AXValueGetValue(axValue as! AXValue, .cgSize, &size) else {
            return nil
        }
        return size
    }

    private func shouldCollectText(for role: String) -> Bool {
        blockedRoles.contains(role) == false
    }

    private func childPriority(for role: String) -> Int {
        if primaryContentRoles.contains(role) {
            return 4
        }
        if secondaryContentRoles.contains(role) {
            return 3
        }
        if role == "AXTextField" {
            return 1
        }
        if blockedRoles.contains(role) {
            return 0
        }
        return 2
    }

}

private struct TextFragment {
    let text: String
    let frame: CGRect?
}

private enum KakaoTalkSpeaker {
    case me
    case them
    case unknown

    var prefix: String? {
        switch self {
        case .me:
            return "Me: "
        case .them:
            return "Them: "
        case .unknown:
            return nil
        }
    }
}

private struct AnnotatedTextLine: Comparable {
    let text: String
    let speaker: KakaoTalkSpeaker
    let frame: CGRect?

    var displayText: String {
        if let prefix = speaker.prefix {
            return prefix + text
        }
        return text
    }

    static func < (lhs: AnnotatedTextLine, rhs: AnnotatedTextLine) -> Bool {
        let lhsY = lhs.frame?.minY ?? .greatestFiniteMagnitude
        let rhsY = rhs.frame?.minY ?? .greatestFiniteMagnitude
        if abs(lhsY - rhsY) > 6 {
            return lhsY < rhsY
        }

        let lhsX = lhs.frame?.minX ?? .greatestFiniteMagnitude
        let rhsX = rhs.frame?.minX ?? .greatestFiniteMagnitude
        if lhsX != rhsX {
            return lhsX < rhsX
        }

        return lhs.displayText < rhs.displayText
    }
}

private struct PrioritizedChild {
    let element: AXUIElement
    let priority: Int
    let order: Int
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private extension Array where Element == AnnotatedTextLine {
    func deduplicatedByNormalizedText() -> [AnnotatedTextLine] {
        var seen = Set<String>()
        return filter { line in
            seen.insert(line.displayText.normalizedComparisonKey).inserted
        }
    }
}

private extension String {
    var normalizedComparisonKey: String {
        lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }
}

private let blockedRoles: Set<String> = [
    "AXButton",
    "AXCheckBox",
    "AXDisclosureTriangle",
    "AXImage",
    "AXIncrementor",
    "AXMenu",
    "AXMenuBar",
    "AXMenuBarItem",
    "AXMenuButton",
    "AXPopUpButton",
    "AXRadioButton",
    "AXScrollBar",
    "AXTab",
    "AXTabGroup",
    "AXToolbar",
    "AXWindow",
]

private let primaryContentRoles: Set<String> = [
    "AXBrowser",
    "AXCell",
    "AXDocument",
    "AXHeading",
    "AXLayoutArea",
    "AXList",
    "AXListItem",
    "AXOutline",
    "AXRow",
    "AXScrollArea",
    "AXStaticText",
    "AXTable",
    "AXTextArea",
    "AXWebArea",
]

private let secondaryContentRoles: Set<String> = [
    "AXGroup",
    "AXSplitGroup",
]
