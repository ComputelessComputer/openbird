import Foundation
import Testing
@testable import OpenbirdKit

struct ProviderConnectionAdvisorTests {
    @Test func picksSuggestedChatModelPerProvider() {
        let googleModels = [
            ProviderModelInfo(
                id: "text-embedding-004",
                supportedGenerationMethods: ["embedContent"]
            ),
            ProviderModelInfo(
                id: "gemini-2.5-flash-preview-05-20",
                canonicalID: "gemini-2.5-flash",
                supportedGenerationMethods: ["generateContent"]
            ),
            ProviderModelInfo(
                id: "gemini-2.5-flash",
                supportedGenerationMethods: ["generateContent"]
            ),
        ]

        #expect(
            ProviderConnectionAdvisor.suggestedChatModel(from: googleModels, for: .google) == "gemini-2.5-flash"
        )
        #expect(ProviderConnectionAdvisor.suggestedEmbeddingModel(from: googleModels) == "text-embedding-004")
    }

    @Test func recognizesPlaceholderModelNames() {
        #expect(ProviderConnectionAdvisor.shouldReplaceChatModel("local-model"))
        #expect(ProviderConnectionAdvisor.shouldReplaceEmbeddingModel("text-embedding-model"))
        #expect(ProviderConnectionAdvisor.shouldReplaceChatModel("") == true)
        #expect(ProviderConnectionAdvisor.shouldReplaceEmbeddingModel("nomic-embed-text") == false)
    }

    @Test func detectsEmbeddingModels() {
        #expect(ProviderConnectionAdvisor.isEmbeddingModel("text-embedding-3-large"))
        #expect(ProviderConnectionAdvisor.isEmbeddingModel("nomic-embed-text"))
        #expect(ProviderConnectionAdvisor.isEmbeddingModel("claude-sonnet-4-5") == false)
    }

    @Test func filtersOpenAIToCurrentTextAliases() {
        let models = [
            ProviderModelInfo(id: "gpt-4o"),
            ProviderModelInfo(id: "gpt-4o-2024-08-06"),
            ProviderModelInfo(id: "gpt-4o-audio-preview"),
            ProviderModelInfo(id: "gpt-3.5-turbo"),
            ProviderModelInfo(id: "tts-1"),
            ProviderModelInfo(id: "omni-moderation-latest"),
            ProviderModelInfo(id: "gpt-5.4-mini"),
            ProviderModelInfo(id: "gpt-5.4-mini-2026-03-17"),
        ]

        #expect(ProviderConnectionAdvisor.visibleChatModels(from: models, for: .openAI).map(\.id) == [
            "gpt-5.4-mini",
            "gpt-4o",
        ])
    }

    @Test func filtersGoogleUsingSupportedGenerationMethods() {
        let models = [
            ProviderModelInfo(
                id: "gemini-embedding-001",
                canonicalID: "gemini-embedding-001",
                supportedGenerationMethods: ["embedContent"]
            ),
            ProviderModelInfo(
                id: "gemini-2.5-pro-preview-03-25",
                canonicalID: "gemini-2.5-pro",
                supportedGenerationMethods: ["generateContent"]
            ),
            ProviderModelInfo(
                id: "gemini-2.5-pro",
                canonicalID: "gemini-2.5-pro",
                supportedGenerationMethods: ["generateContent"]
            ),
        ]

        #expect(ProviderConnectionAdvisor.visibleChatModels(from: models, for: .google).map(\.id) == [
            "gemini-2.5-pro",
        ])
    }

    @Test func filtersOpenRouterToTextModelsAndDeduplicatesCanonicalIDs() {
        let older = Date(timeIntervalSince1970: 10)
        let newer = Date(timeIntervalSince1970: 20)
        let models = [
            ProviderModelInfo(
                id: "openai/gpt-5.4",
                canonicalID: "openai/gpt-5.4",
                createdAt: newer,
                outputModalities: ["text"]
            ),
            ProviderModelInfo(
                id: "openai/gpt-5.4-2026-03-01",
                canonicalID: "openai/gpt-5.4",
                createdAt: older,
                outputModalities: ["text"]
            ),
            ProviderModelInfo(
                id: "openai/gpt-image-1.5",
                canonicalID: "openai/gpt-image-1.5",
                outputModalities: ["image"]
            ),
        ]

        #expect(ProviderConnectionAdvisor.visibleChatModels(from: models, for: .openRouter).map(\.id) == [
            "openai/gpt-5.4",
        ])
    }

    @Test func keepsHeuristicFallbackForOpenAICompatibleAndOllama() {
        let models = [
            ProviderModelInfo(id: "qwen3"),
            ProviderModelInfo(id: "nomic-embed-text"),
            ProviderModelInfo(id: "tts-1"),
            ProviderModelInfo(id: "llama3.2"),
        ]

        #expect(ProviderConnectionAdvisor.visibleChatModels(from: models, for: .openAICompatible).map(\.id) == [
            "qwen3",
            "llama3.2",
        ])
        #expect(ProviderConnectionAdvisor.visibleChatModels(from: models, for: .ollama).map(\.id) == [
            "qwen3",
            "llama3.2",
        ])
    }
}
