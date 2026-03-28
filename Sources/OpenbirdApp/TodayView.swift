import SwiftUI
import OpenbirdKit

struct TodayView: View {
    @ObservedObject var model: AppModel
    @State private var isShowingSupportingEvidence = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                DatePicker("Day", selection: Binding(
                    get: { model.selectedDay },
                    set: { model.selectDay($0) }
                ), displayedComponents: .date)
                .datePickerStyle(.compact)

                Spacer()

                Button("Inspect Evidence") {
                    model.isShowingRawLogInspector = true
                }
                Button("Generate Summary") {
                    model.generateTodayJournal()
                }
                .buttonStyle(.borderedProminent)
            }

            if let journal = model.todayJournal {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if model.needsOnboarding {
                            SetupChecklistView(model: model)
                        }
                        summaryHeader(journal)
                        summaryCard(journal.markdown)

                        if journal.sections.isEmpty == false {
                            DisclosureGroup(isExpanded: $isShowingSupportingEvidence) {
                                VStack(alignment: .leading, spacing: 14) {
                                    ForEach(journal.sections) { section in
                                        sectionCard(section)
                                    }
                                }
                                .padding(.top, 12)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Supporting Evidence")
                                        .font(.headline)
                                    Text("Grouped source material used to generate this summary.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(20)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 20))
                        }
                    }
                    .frame(maxWidth: 860, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    if model.needsOnboarding {
                        SetupChecklistView(model: model)
                    }

                    ContentUnavailableView(
                        "No daily summary yet",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Capture some activity, then generate a clean summary from your local logs.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(28)
        .navigationTitle("Today")
    }

    private func summaryHeader(_ journal: DailyJournal) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Daily Summary")
                .font(.system(size: 30, weight: .semibold))

            HStack(spacing: 10) {
                Label(summaryStatusTitle(for: journal), systemImage: journal.providerID == nil ? "sparkles.slash" : "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(summaryStatusBackground(for: journal), in: Capsule())

                if let providerName = model.providerName(for: journal.providerID) {
                    Text(providerName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(summaryStatusDescription(for: journal))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func summaryCard(_ markdown: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SummaryMarkdownView(markdown: markdown)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 24))
    }

    private func summaryStatusTitle(for journal: DailyJournal) -> String {
        journal.providerID == nil ? "Fallback Summary" : "LLM Summary"
    }

    private func summaryStatusDescription(for journal: DailyJournal) -> String {
        if journal.providerID == nil {
            return "This review used the local fallback formatter. Connect a model in Settings to generate a more polished LLM summary from the same evidence."
        }
        return "Generated from your local activity logs. Openbird keeps the supporting evidence available for inspection."
    }

    private func summaryStatusBackground(for journal: DailyJournal) -> Color {
        journal.providerID == nil ? Color.orange.opacity(0.16) : Color.blue.opacity(0.14)
    }

    private func sectionCard(_ section: JournalSection) -> some View {
        let event = representativeEvent(for: section)

        return HStack(alignment: .top, spacing: 12) {
            ActivityAppIcon(
                bundleId: event?.bundleId,
                appName: event?.appName ?? section.heading,
                size: 30
            )
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 8) {
                Text("\(section.timeRange) • \(section.heading)")
                    .font(.headline)
                ForEach(section.bullets, id: \.self) { bullet in
                    Text("• \(bullet)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 18))
    }

    private func representativeEvent(for section: JournalSection) -> ActivityEvent? {
        let sourceEventIDs = Set(section.sourceEventIDs)
        return model.rawEvents.first { sourceEventIDs.contains($0.id) }
    }
}

private struct SummaryMarkdownView: View {
    private let blocks: [SummaryMarkdownBlock]

    init(markdown: String) {
        blocks = SummaryMarkdownParser.parse(markdown)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(blocks.indices, id: \.self) { index in
                blockView(blocks[index])
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(_ block: SummaryMarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            inlineMarkdownText(text)
                .font(level == 1 ? .system(size: 24, weight: .semibold) : .title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .paragraph(let text):
            inlineMarkdownText(text)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .list(let items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(items.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)

                        inlineMarkdownText(items[index])
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func inlineMarkdownText(_ markdown: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attributed = try? AttributedString(markdown: markdown, options: options) {
            return Text(attributed)
        }
        return Text(markdown)
    }
}

private enum SummaryMarkdownBlock {
    case heading(level: Int, text: String)
    case paragraph(String)
    case list([String])
}

private enum SummaryMarkdownParser {
    static func parse(_ markdown: String) -> [SummaryMarkdownBlock] {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var blocks: [SummaryMarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                index += 1
                continue
            }

            if let heading = heading(from: line) {
                blocks.append(.heading(level: heading.level, text: heading.text))
                index += 1
                continue
            }

            if let item = listItem(from: line) {
                var items = [item]
                index += 1

                while index < lines.count {
                    let next = lines[index].trimmingCharacters(in: .whitespaces)
                    guard let nextItem = listItem(from: next) else { break }
                    items.append(nextItem)
                    index += 1
                }

                blocks.append(.list(items))
                continue
            }

            var paragraphLines = [line]
            index += 1

            while index < lines.count {
                let next = lines[index].trimmingCharacters(in: .whitespaces)
                if next.isEmpty || heading(from: next) != nil || listItem(from: next) != nil {
                    break
                }
                paragraphLines.append(next)
                index += 1
            }

            blocks.append(.paragraph(paragraphLines.joined(separator: " ")))
        }

        if blocks.count > 1,
           let first = blocks.first,
           case .heading(let level, _) = first,
           level == 1 {
            blocks.removeFirst()
        }

        return blocks.isEmpty ? [.paragraph(markdown)] : blocks
    }

    private static func heading(from line: String) -> (level: Int, text: String)? {
        let level = line.prefix { $0 == "#" }.count
        guard (1...3).contains(level) else { return nil }

        let markerEnd = line.index(line.startIndex, offsetBy: level)
        let content = line[markerEnd...].trimmingCharacters(in: .whitespaces)
        guard content.isEmpty == false else { return nil }
        return (level, content)
    }

    private static func listItem(from line: String) -> String? {
        let markers = ["- ", "* "]
        for marker in markers where line.hasPrefix(marker) {
            let item = String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
            return item.isEmpty ? nil : item
        }
        return nil
    }
}
