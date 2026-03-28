import Foundation

public enum ProviderConnectionAdvisor {
    public static func suggestedChatModel(from models: [ProviderModelInfo], for kind: ProviderKind) -> String? {
        visibleChatModels(from: models, for: kind).first?.id
    }

    public static func suggestedEmbeddingModel(from models: [ProviderModelInfo]) -> String? {
        models
            .map(\.id)
            .first(where: isEmbeddingModel)
    }

    public static func visibleChatModels(from models: [ProviderModelInfo], for kind: ProviderKind) -> [ProviderModelInfo] {
        switch kind {
        case .openAI:
            return currentOpenAITextModels(from: models)
        case .anthropic:
            return currentAnthropicTextModels(from: models)
        case .google:
            return currentGoogleTextModels(from: models)
        case .openRouter:
            return currentOpenRouterTextModels(from: models)
        case .openAICompatible, .ollama:
            return heuristicChatModels(from: models)
        }
    }

    public static func shouldReplaceChatModel(_ current: String) -> Bool {
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty || trimmed == "local-model"
    }

    public static func shouldReplaceEmbeddingModel(_ current: String) -> Bool {
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty || trimmed == "text-embedding-model"
    }

    public static func isEmbeddingModel(_ value: String) -> Bool {
        let lowered = value.lowercased()
        let embeddingHints = [
            "embed",
            "embedding",
            "nomic",
            "bge",
            "e5",
            "gte",
        ]
        return embeddingHints.contains { lowered.contains($0) }
    }

    static func canonicalChatModelID(_ value: String) -> String {
        var candidate = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        while let range = candidate.range(
            of: #"-(\d{4}-\d{2}-\d{2}|\d{4}|\d{3}|\d{2})$"#,
            options: .regularExpression
        ) {
            candidate.removeSubrange(range)
        }

        return candidate
    }

    private static func currentOpenAITextModels(from models: [ProviderModelInfo]) -> [ProviderModelInfo] {
        let preferredAliases = [
            "gpt-5.4",
            "gpt-5.4-mini",
            "gpt-5.4-nano",
            "gpt-oss-120b",
            "gpt-oss-20b",
            "o3",
            "o4-mini",
            "gpt-4.1",
            "gpt-4.1-mini",
            "gpt-4.1-nano",
            "gpt-4o",
            "gpt-4o-mini",
        ]

        let visibleByID = Dictionary(
            uniqueKeysWithValues: heuristicChatModels(from: models).map {
                ($0.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), $0)
            }
        )

        let preferred = preferredAliases.compactMap { visibleByID[$0] }
        return preferred.isEmpty ? heuristicChatModels(from: models) : preferred
    }

    private static func currentAnthropicTextModels(from models: [ProviderModelInfo]) -> [ProviderModelInfo] {
        let claudeModels = models.filter {
            $0.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("claude")
        }

        return claudeModels.sorted {
            switch ($0.createdAt, $1.createdAt) {
            case let (lhs?, rhs?):
                return lhs > rhs
            default:
                return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
        }
    }

    private static func currentGoogleTextModels(from models: [ProviderModelInfo]) -> [ProviderModelInfo] {
        let textModels = models.filter { model in
            model.supportedGenerationMethods.contains("generateContent")
        }

        return deduplicatedModels(from: textModels) { model in
            let canonical = model.canonicalID?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return canonical.flatMap { $0.isEmpty ? nil : $0 } ?? canonicalChatModelID(model.id)
        }
    }

    private static func currentOpenRouterTextModels(from models: [ProviderModelInfo]) -> [ProviderModelInfo] {
        let textModels = models.filter { model in
            let modalities = Set(model.outputModalities.map { $0.lowercased() })
            let allowsText = modalities.isEmpty || modalities.contains("text")
            return allowsText && model.isDeprecated == false
        }

        return deduplicatedModels(from: textModels) { model in
            let canonical = model.canonicalID?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return canonical.flatMap { $0.isEmpty ? nil : $0 } ?? canonicalChatModelID(model.id)
        }
    }

    private static func heuristicChatModels(from models: [ProviderModelInfo]) -> [ProviderModelInfo] {
        let visibleModels = models.filter { isHeuristicChatModel($0.id) }
        let visibleIDs = Set(visibleModels.map {
            $0.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        })

        return visibleModels.filter { model in
            let modelID = model.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let canonicalID = canonicalChatModelID(model.id)
            if canonicalID == modelID {
                return true
            }
            return visibleIDs.contains(canonicalID) == false
        }
    }

    private static func isHeuristicChatModel(_ value: String) -> Bool {
        let lowered = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard lowered.isEmpty == false, isEmbeddingModel(lowered) == false else {
            return false
        }

        let blockedPrefixes = [
            "tts-",
            "text-to-speech",
            "dall-e",
            "whisper",
            "omni-moderation",
            "text-moderation",
            "babbage",
            "davinci",
        ]
        if blockedPrefixes.contains(where: lowered.hasPrefix) {
            return false
        }

        let blockedTerms = [
            "audio-preview",
            "realtime-preview",
            "transcribe",
            "moderation",
            "image-generation",
            "image-preview",
            "speech",
            "instruct",
            "rerank",
        ]
        return blockedTerms.contains(where: lowered.contains) == false
    }

    private static func deduplicatedModels(
        from models: [ProviderModelInfo],
        key: (ProviderModelInfo) -> String
    ) -> [ProviderModelInfo] {
        let groups = Dictionary(grouping: models, by: key)
        return groups.keys.compactMap { key in
            groups[key]?.sorted { preferredModelSort(lhs: $0, rhs: $1) }.first
        }
        .sorted { preferredModelSort(lhs: $0, rhs: $1) }
    }

    private static func preferredModelSort(lhs: ProviderModelInfo, rhs: ProviderModelInfo) -> Bool {
        let lhsAlias = normalizedAlias(lhs)
        let rhsAlias = normalizedAlias(rhs)
        if lhsAlias != rhsAlias {
            return lhsAlias
        }

        switch (lhs.createdAt, rhs.createdAt) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate > rhsDate
        default:
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    private static func normalizedAlias(_ model: ProviderModelInfo) -> Bool {
        guard let canonicalID = model.canonicalID?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              canonicalID.isEmpty == false else {
            return canonicalChatModelID(model.id) == model.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        return canonicalID == model.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
