import SwiftUI
import OpenbirdKit

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var newExclusionPattern = ""
    @State private var exclusionKind: ExclusionKind = .bundleID
    private let bundleIDSuggestionLimit = 8

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                providerSection
                captureSection
                exclusionSection
                deleteSection
            }
            .padding(28)
        }
        .navigationTitle("Settings")
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Providers")
                .font(.title3.bold())

            Picker("Provider", selection: Binding(
                get: { model.editingProvider.kind },
                set: { model.selectProviderKind($0) }
            )) {
                ForEach(ProviderKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .frame(maxWidth: 280)

            if let providerDescription {
                Text(providerDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if model.editingProvider.kind.showsBaseURLField {
                TextField("Endpoint", text: $model.editingProvider.baseURL)
            }
            if model.editingProvider.kind.showsAPIKeyField {
                TextField(model.editingProvider.kind.requiresAPIKey ? "API key" : "API key (optional)", text: $model.editingProvider.apiKey)
            }
            if model.availableChatModels.isEmpty == false {
                Picker("Chat model", selection: modelSelection(
                    text: $model.editingProvider.chatModel,
                    models: model.availableChatModels
                )) {
                    Text("Select model").tag("")
                    ForEach(model.availableChatModels) { providerModel in
                        Text(providerModel.displayName).tag(providerModel.id)
                    }
                }
                .frame(maxWidth: 360)
            } else if model.editingProvider.chatModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                LabeledContent("Chat model", value: model.editingProvider.chatModel)
            }
            if model.editingProvider.kind.supportsEmbeddings {
                if model.availableEmbeddingModels.isEmpty == false {
                    Picker("Embedding model", selection: modelSelection(
                        text: $model.editingProvider.embeddingModel,
                        models: model.availableEmbeddingModels,
                        allowsEmptySelection: true
                    )) {
                        Text("None").tag("")
                        ForEach(model.availableEmbeddingModels) { providerModel in
                            Text(providerModel.displayName).tag(providerModel.id)
                        }
                    }
                    .frame(maxWidth: 360)
                } else if model.editingProvider.embeddingModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    LabeledContent("Embedding model", value: model.editingProvider.embeddingModel)
                }
            }

            if model.providerStatusMessage.isEmpty == false {
                Text(model.providerStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            model.scheduleAutomaticProviderConnectionCheckIfNeeded()
        }
        .onChange(of: model.editingProvider.apiKey) { _, _ in
            model.scheduleAutomaticProviderConnectionCheckIfNeeded()
        }
        .onChange(of: model.editingProvider.baseURL) { _, _ in
            model.scheduleAutomaticProviderConnectionCheckIfNeeded()
        }
    }

    private var providerDescription: String? {
        switch model.editingProvider.kind {
        case .ollama:
            return "Runs fully local. Default endpoint is 127.0.0.1:11434."
        case .openAICompatible:
            return "Use this for LM Studio, vLLM, LocalAI, or any OpenAI-compatible endpoint."
        case .openAI:
            return "Uses your OpenAI API key with the standard OpenAI API."
        case .anthropic:
            return "Uses Claude for journal generation and chat. Embeddings stay on local search."
        case .google:
            return "Uses a Gemini API key from Google AI Studio."
        case .openRouter:
            return "Uses one OpenRouter key to access many hosted models."
        }
    }

    private var captureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Capture")
                .font(.title3.bold())
            Toggle("Pause capture", isOn: Binding(
                get: { model.settings.capturePaused },
                set: { _ in model.toggleCapturePaused() }
            ))
            Stepper("Retention days: \(model.settings.retentionDays)", value: Binding(
                get: { model.settings.retentionDays },
                set: { model.updateRetentionDays($0) }
            ), in: 1...90)
        }
    }

    private var exclusionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exclusions")
                .font(.title3.bold())
            HStack {
                Picker("Type", selection: $exclusionKind) {
                    Text("Bundle ID").tag(ExclusionKind.bundleID)
                    Text("Domain").tag(ExclusionKind.domain)
                }
                .frame(width: 160)
                TextField(
                    exclusionKind == .bundleID ? "Search installed apps or enter bundle ID" : "example.com",
                    text: $newExclusionPattern
                )
                .onSubmit(addCurrentExclusion)
                Button("Add") {
                    addCurrentExclusion()
                }
                .disabled(trimmedNewExclusionPattern.isEmpty)
            }

            if exclusionKind == .bundleID {
                bundleIDSuggestionSection
            }

            ForEach(model.exclusions) { exclusion in
                HStack {
                    VStack(alignment: .leading) {
                        if exclusion.kind == .bundleID,
                           let appName = model.installedApplicationName(for: exclusion.pattern) {
                            Text(appName)
                            Text(exclusion.pattern)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(exclusion.pattern)
                        }
                        Text(exclusion.kind == .bundleID ? "Bundle ID" : "Domain")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Remove") {
                        model.removeExclusion(id: exclusion.id)
                    }
                }
                .padding(14)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    @ViewBuilder
    private var bundleIDSuggestionSection: some View {
        if model.isLoadingInstalledApplications {
            Text("Loading installed apps…")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if bundleIDSuggestions.isEmpty == false {
            VStack(spacing: 0) {
                ForEach(bundleIDSuggestions) { application in
                    Button {
                        model.addExclusion(kind: .bundleID, pattern: application.bundleID)
                        newExclusionPattern = ""
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(application.name)
                                    .foregroundStyle(.primary)
                                Text(application.bundleID)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Add")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if application.id != bundleIDSuggestions.last?.id {
                        Divider()
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
        } else if trimmedNewExclusionPattern.isEmpty == false {
            Text("No matching installed apps. You can still enter a bundle ID manually.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Delete data")
                .font(.title3.bold())
            ControlGroup {
                Button("Last hour") { model.deleteData(scope: .lastHour) }
                Button("Last day") { model.deleteData(scope: .lastDay) }
                Button("All") { model.deleteData(scope: .all) }
            }
        }
    }

    private func modelSelection(
        text: Binding<String>,
        models: [ProviderModelInfo],
        allowsEmptySelection: Bool = false
    ) -> Binding<String> {
        Binding(
            get: {
                let value = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                return models.contains(where: { $0.id == value }) ? value : ""
            },
            set: { selection in
                guard selection.isEmpty == false else {
                    if allowsEmptySelection {
                        text.wrappedValue = ""
                        model.scheduleAutomaticProviderSaveIfNeeded()
                    }
                    return
                }
                text.wrappedValue = selection
                model.scheduleAutomaticProviderSaveIfNeeded()
            }
        )
    }

    private var trimmedNewExclusionPattern: String {
        newExclusionPattern.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var excludedBundleIDs: Set<String> {
        Set(
            model.exclusions
                .filter { $0.kind == .bundleID }
                .map { $0.pattern.lowercased() }
        )
    }

    private var bundleIDSuggestions: [InstalledApplication] {
        let query = trimmedNewExclusionPattern

        return Array(
            model.installedApplications
                .filter { application in
                    guard excludedBundleIDs.contains(application.bundleID.lowercased()) == false else {
                        return false
                    }

                    guard query.isEmpty == false else {
                        return true
                    }

                    return application.name.localizedCaseInsensitiveContains(query)
                        || application.bundleID.localizedCaseInsensitiveContains(query)
                }
                .prefix(bundleIDSuggestionLimit)
        )
    }

    private func addCurrentExclusion() {
        model.addExclusion(kind: exclusionKind, pattern: trimmedNewExclusionPattern)
        newExclusionPattern = ""
    }
}
