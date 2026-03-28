import Foundation

public struct GroupedActivityEvent: Identifiable, Hashable, Sendable {
    public let id: String
    public let startedAt: Date
    public let endedAt: Date
    public let bundleId: String
    public let appName: String
    public let detailTitle: String?
    public let url: String?
    public let excerpt: String
    public let isExcluded: Bool
    public let sourceEvents: [ActivityEvent]

    public init(
        id: String,
        startedAt: Date,
        endedAt: Date,
        bundleId: String,
        appName: String,
        detailTitle: String?,
        url: String?,
        excerpt: String,
        isExcluded: Bool,
        sourceEvents: [ActivityEvent]
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.bundleId = bundleId
        self.appName = appName
        self.detailTitle = detailTitle
        self.url = url
        self.excerpt = excerpt
        self.isExcluded = isExcluded
        self.sourceEvents = sourceEvents
    }

    public var displayTitle: String {
        detailTitle ?? appName
    }

    public var sourceEventIDs: [String] {
        sourceEvents.map(\.id)
    }

    public var sourceEventCount: Int {
        sourceEvents.count
    }
}

public enum ActivityEvidencePreprocessor {
    private static let maxMergeGap: TimeInterval = 5 * 60
    private static let chromePhrases = [
        "enter a message",
        "voice call",
        "video call",
        "new message",
        "all folder",
        "unread folder",
        "chatroom",
        "search",
        "menu",
        "profile",
        "friends",
        "folder",
        "chats",
    ]

    public static func groupedMeaningfulEvents(from events: [ActivityEvent]) -> [GroupedActivityEvent] {
        let meaningfulEvents = events.filter(isMeaningful)
        guard let firstEvent = meaningfulEvents.first else {
            return []
        }

        var groups = [makeGroup(from: [firstEvent])]
        for event in meaningfulEvents.dropFirst() {
            guard let lastGroup = groups.last else {
                groups.append(makeGroup(from: [event]))
                continue
            }

            if shouldMerge(lastGroup, with: event) {
                groups[groups.count - 1] = makeGroup(from: lastGroup.sourceEvents + [event])
            } else {
                groups.append(makeGroup(from: [event]))
            }
        }

        return groups
    }

    public static func isMeaningful(_ event: ActivityEvent) -> Bool {
        if event.bundleId == "com.apple.loginwindow" || normalizedComparisonKey(for: event.appName) == "loginwindow" {
            return false
        }

        return descriptorComponents(for: [event]).isEmpty == false
    }

    public static func cleanedExcerpt(for event: ActivityEvent) -> String {
        descriptorComponents(for: [event]).excerpt ?? ""
    }

    public static func summarizedURL(from urlString: String?) -> String? {
        guard let urlString,
              urlString.isEmpty == false
        else {
            return nil
        }

        guard let components = URLComponents(string: urlString),
              let host = components.host
        else {
            return String(urlString.prefix(80))
        }

        let normalizedHost = host.replacingOccurrences(of: "www.", with: "")
        let path = components.path == "/" ? "" : components.path
        let summary = normalizedHost + path

        if summary.isEmpty {
            return normalizedHost
        }

        return summary.count > 80 ? String(summary.prefix(80)) + "…" : summary
    }

    private static func shouldMerge(_ group: GroupedActivityEvent, with event: ActivityEvent) -> Bool {
        guard group.bundleId == event.bundleId, group.isExcluded == event.isExcluded else {
            return false
        }

        let gap = event.startedAt.timeIntervalSince(group.endedAt)
        guard gap <= maxMergeGap else {
            return false
        }

        if group.sourceEvents.contains(where: { $0.contentHash == event.contentHash }) {
            return true
        }

        let groupDescriptors = descriptorComponents(for: group.sourceEvents)
        let eventDescriptors = descriptorComponents(for: [event])

        if groupDescriptors.detailTitles.isDisjoint(with: eventDescriptors.detailTitles) == false {
            return true
        }

        if groupDescriptors.urls.isDisjoint(with: eventDescriptors.urls) == false {
            return true
        }

        if groupDescriptors.excerpts.isDisjoint(with: eventDescriptors.excerpts) == false {
            return true
        }

        return false
    }

    private static func makeGroup(from events: [ActivityEvent]) -> GroupedActivityEvent {
        let descriptors = descriptorComponents(for: events)

        return GroupedActivityEvent(
            id: events.first?.id ?? UUID().uuidString,
            startedAt: events.map(\.startedAt).min() ?? Date(),
            endedAt: events.map(\.endedAt).max() ?? Date(),
            bundleId: events.first?.bundleId ?? "",
            appName: events.first?.appName ?? "Activity",
            detailTitle: descriptors.preferredDetailTitle,
            url: descriptors.preferredURL,
            excerpt: descriptors.displayExcerpt,
            isExcluded: events.contains(where: \.isExcluded),
            sourceEvents: events
        )
    }

    private static func descriptorComponents(for events: [ActivityEvent]) -> DescriptorComponents {
        var detailTitles = Set<String>()
        var urls = Set<String>()
        var excerpts = Set<String>()
        var preferredDetailTitle: String?
        var preferredURL: String?
        var excerptPieces: [String] = []

        for event in events {
            if let detailTitle = cleanText(event.detailTitle) {
                let key = normalizedComparisonKey(for: detailTitle)
                if key.isEmpty == false {
                    detailTitles.insert(key)
                    if preferredDetailTitle == nil || detailTitle.count > (preferredDetailTitle?.count ?? 0) {
                        preferredDetailTitle = detailTitle
                    }
                }
            }

            if let rawURL = cleanText(event.url),
               let urlSummary = summarizedURL(from: rawURL) {
                let key = normalizedComparisonKey(for: urlSummary)
                if key.isEmpty == false {
                    urls.insert(key)
                    if preferredURL == nil || urlSummary.count > (summarizedURL(from: preferredURL)?.count ?? 0) {
                        preferredURL = rawURL
                    }
                }
            }

            if let excerpt = cleanedVisibleText(
                event.visibleText,
                excluding: [event.appName, event.windowTitle]
            ) {
                let key = normalizedComparisonKey(for: excerpt)
                if key.isEmpty == false {
                    excerpts.insert(key)
                    if excerptPieces.contains(where: { normalizedComparisonKey(for: $0) == key }) == false {
                        excerptPieces.append(excerpt)
                    }
                }
            }
        }

        let displayExcerpt = excerptPieces.prefix(2).joined(separator: " • ")
        return DescriptorComponents(
            detailTitles: detailTitles,
            urls: urls,
            excerpts: excerpts,
            preferredDetailTitle: preferredDetailTitle,
            preferredURL: preferredURL,
            excerpt: excerptPieces.first,
            displayExcerpt: displayExcerpt.count > 220 ? String(displayExcerpt.prefix(219)) + "…" : displayExcerpt
        )
    }

    private static func cleanedVisibleText(_ text: String, excluding values: [String]) -> String? {
        var cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(
                of: #"\b\d{1,2}:\d{2}\s?(?:AM|PM)\b"#,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: #"\b\d+\s+friends?\b"#,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )

        for phrase in chromePhrases {
            cleaned = cleaned.replacingOccurrences(
                of: "\\b\(NSRegularExpression.escapedPattern(for: phrase))\\b",
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        cleaned = cleaned
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.isEmpty == false else {
            return nil
        }

        let cleanedKey = normalizedComparisonKey(for: cleaned)
        guard cleanedKey.isEmpty == false else {
            return nil
        }

        let excludedKeys = values
            .compactMap(cleanText)
            .map(normalizedComparisonKey(for:))
            .filter { $0.isEmpty == false }

        guard excludedKeys.contains(cleanedKey) == false else {
            return nil
        }

        return cleaned.count > 180 ? String(cleaned.prefix(179)) + "…" : cleaned
    }

    private static func cleanText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedComparisonKey(for value: String) -> String {
        value.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }
}

private struct DescriptorComponents {
    let detailTitles: Set<String>
    let urls: Set<String>
    let excerpts: Set<String>
    let preferredDetailTitle: String?
    let preferredURL: String?
    let excerpt: String?
    let displayExcerpt: String

    var isEmpty: Bool {
        detailTitles.isEmpty && urls.isEmpty && excerpts.isEmpty
    }
}
