import Foundation

public struct ExclusionEngine {
    public init() {}

    public func isExcluded(snapshot: WindowSnapshot, rules: [ExclusionRule]) -> Bool {
        let snapshotDomain = normalizedDomain(from: snapshot.url)

        for rule in rules where rule.isEnabled {
            switch rule.kind {
            case .bundleID:
                if snapshot.bundleId.caseInsensitiveCompare(rule.pattern) == .orderedSame {
                    return true
                }
            case .domain:
                guard let snapshotDomain,
                      let excludedDomain = normalizedDomain(from: rule.pattern)
                else {
                    continue
                }

                if snapshotDomain == excludedDomain || snapshotDomain.hasSuffix(".\(excludedDomain)") {
                    return true
                }
            }
        }
        return false
    }

    private func normalizedDomain(from value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.isEmpty == false
        else {
            return nil
        }

        let candidates = value.contains("://") ? [value] : [value, "https://\(value)"]
        for candidate in candidates {
            if let host = URLComponents(string: candidate)?.host?.lowercased(),
               host.isEmpty == false {
                return host
            }
        }

        return nil
    }
}
