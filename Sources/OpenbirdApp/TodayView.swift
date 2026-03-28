import SwiftUI
import OpenbirdKit

struct TodayView: View {
    @ObservedObject var model: AppModel
    @State private var timelineItems: [TimelineItem] = []
    @State private var isPreparingTimeline = false
    @State private var isChatExpanded = false
    @FocusState private var focusedField: TodayChatDock.FocusField?
    private let collapsedChatClearance: CGFloat = 92
    private let expandedChatClearance: CGFloat = 420
    private static let selectedDayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "MMMM"
        return formatter
    }()
    private static let selectedDayYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if model.needsOnboarding {
                        SetupChecklistView(model: model)
                    }

                    if isPreparingTimeline && timelineItems.isEmpty {
                        ProgressView("Loading timeline…")
                            .frame(maxWidth: .infinity, minHeight: 280)
                    } else if timelineItems.isEmpty {
                        ContentUnavailableView(
                            "No activity yet",
                            systemImage: "clock.badge.questionmark",
                            description: Text("Openbird will show a timeline of your day here once it captures some activity.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 280)
                    } else {
                        timelineCard
                    }
                }
                .padding(.bottom, chatClearance)
                .frame(maxWidth: 860, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay {
            if isChatExpanded {
                Rectangle()
                    .fill(Color.black.opacity(0.001))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        collapseChat()
                    }
            }
        }
        .overlay(alignment: .bottom) {
            TodayChatDock(
                model: model,
                isExpanded: $isChatExpanded,
                focusedField: $focusedField
            )
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .onAppear {
            handleChatFocusRequestIfNeeded()
        }
        .onChange(of: model.shouldFocusChatComposer) { _, _ in
            handleChatFocusRequestIfNeeded()
        }
        .onExitCommand {
            collapseChat()
        }
        .task(id: timelinePreparationKey) {
            await prepareTimeline()
        }
    }

    private var header: some View {
        HStack {
            Text(selectedDayTitle)
                .font(.title3.bold())

            Spacer()

            ControlGroup {
                Button {
                    stepSelectedDay(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .help("Previous day")

                Button {
                    stepSelectedDay(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .help("Next day")
                .disabled(isShowingToday)
            }

            Button("Inspect Evidence") {
                model.isShowingRawLogInspector = true
            }

            Button {
                model.generateTodayJournal()
            } label: {
                HStack(spacing: 8) {
                    if model.isGeneratingTodayJournal {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(model.isGeneratingTodayJournal ? "Generating…" : "Generate Summary")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isGeneratingTodayJournal)
        }
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(timelineItems.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Divider()
                }
                timelineRow(item)
                    .padding(24)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 24))
    }

    private func timelineRow(_ item: TimelineItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ActivityAppIcon(
                bundleId: item.bundleId,
                bundlePath: item.bundlePath,
                appName: item.appName,
                size: 30
            )
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 8) {
                Text("\(item.timeRange) — \(item.title)")
                    .font(.headline)

                ForEach(item.bullets, id: \.self) { bullet in
                    Text("• \(bullet)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timelinePreparationKey: TimelinePreparationKey {
        TimelinePreparationKey(
            journalID: model.todayJournal?.id,
            rawEventCount: model.rawEvents.count,
            rawEventLastID: model.rawEvents.last?.id,
            installedApplicationCount: model.installedApplications.count
        )
    }

    private func handleChatFocusRequestIfNeeded() {
        guard model.shouldFocusChatComposer else {
            return
        }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
            isChatExpanded = true
        }
        focusedField = .composer
        model.acknowledgeChatFocusRequest()
    }

    private func collapseChat() {
        guard isChatExpanded else {
            return
        }
        focusedField = nil
        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
            isChatExpanded = false
        }
    }

    private var chatClearance: CGFloat {
        isChatExpanded ? expandedChatClearance : collapsedChatClearance
    }

    private var selectedDayTitle: String {
        let day = Calendar.current.component(.day, from: model.selectedDay)
        let month = Self.selectedDayMonthFormatter.string(from: model.selectedDay)
        let year = Self.selectedDayYearFormatter.string(from: model.selectedDay)
        return "\(month) \(day)\(ordinalSuffix(for: day)), \(year)"
    }

    private var isShowingToday: Bool {
        Calendar.current.isDate(model.selectedDay, inSameDayAs: Date())
    }

    private func stepSelectedDay(by offset: Int) {
        let calendar = Calendar.current
        let currentDay = calendar.startOfDay(for: model.selectedDay)
        let today = calendar.startOfDay(for: Date())

        guard let targetDay = calendar.date(byAdding: .day, value: offset, to: currentDay) else {
            return
        }
        guard targetDay <= today else {
            return
        }

        model.selectDay(targetDay)
    }

    private func ordinalSuffix(for day: Int) -> String {
        let lastTwoDigits = day % 100
        if (11...13).contains(lastTwoDigits) {
            return "th"
        }

        switch day % 10 {
        case 1:
            return "st"
        case 2:
            return "nd"
        case 3:
            return "rd"
        default:
            return "th"
        }
    }

    @MainActor
    private func prepareTimeline() async {
        let journalSections = model.todayJournal?.sections ?? []
        let rawEvents = model.rawEvents
        let installedApplications = model.installedApplications

        isPreparingTimeline = true

        let preparationTask = Task.detached(priority: .userInitiated) {
            Self.buildTimelineItems(
                journalSections: journalSections,
                rawEvents: rawEvents,
                installedApplications: installedApplications
            )
        }
        let items = await preparationTask.value

        guard Task.isCancelled == false else {
            return
        }

        timelineItems = items
        isPreparingTimeline = false
    }

    nonisolated private static func buildTimelineItems(
        journalSections: [JournalSection],
        rawEvents: [ActivityEvent],
        installedApplications: [InstalledApplication]
    ) -> [TimelineItem] {
        let meaningfulRawEvents = rawEvents.filter { ActivityEvidencePreprocessor.isMeaningful($0) }
        let groupedRawEvents = ActivityEvidencePreprocessor.groupedMeaningfulEvents(from: rawEvents)
        let applicationsByBundleID = Dictionary(uniqueKeysWithValues: installedApplications.map {
            ($0.bundleID.lowercased(), $0)
        })

        if journalSections.isEmpty == false {
            let eventsByID = Dictionary(uniqueKeysWithValues: meaningfulRawEvents.map { ($0.id, $0) })

            return journalSections.map { section in
                let representativeEvent = section.sourceEventIDs.lazy.compactMap { eventsByID[$0] }.first
                let bundlePath = representativeEvent.flatMap { event in
                    applicationsByBundleID[event.bundleId.lowercased()]?.bundlePath
                }

                return TimelineItem(
                    id: section.id,
                    timeRange: section.timeRange,
                    title: section.heading,
                    bullets: section.bullets,
                    bundleId: representativeEvent?.bundleId,
                    bundlePath: bundlePath,
                    appName: representativeEvent?.appName ?? section.heading
                )
            }
        }

        return groupedRawEvents
            .filter { $0.isExcluded == false }
            .map { event in
                let bundlePath = applicationsByBundleID[event.bundleId.lowercased()]?.bundlePath
                let bulletCandidates: [String] = [
                    ActivityEvidencePreprocessor.summarizedURL(from: event.url),
                    event.excerpt.isEmpty ? nil : event.excerpt,
                    event.sourceEventCount > 1 ? "\(event.sourceEventCount) grouped logs" : nil,
                ].compactMap { value in
                    guard let value else { return nil }
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : trimmed
                }

                return TimelineItem(
                    id: event.id,
                    timeRange: "\(OpenbirdDateFormatting.timeString(for: event.startedAt)) - \(OpenbirdDateFormatting.timeString(for: event.endedAt))",
                    title: event.displayTitle,
                    bullets: bulletCandidates,
                    bundleId: event.bundleId,
                    bundlePath: bundlePath,
                    appName: event.appName
                )
            }
    }
}

private struct TimelineItem: Identifiable, Sendable {
    let id: String
    let timeRange: String
    let title: String
    let bullets: [String]
    let bundleId: String?
    let bundlePath: String?
    let appName: String
}

private struct TimelinePreparationKey: Equatable {
    let journalID: String?
    let rawEventCount: Int
    let rawEventLastID: String?
    let installedApplicationCount: Int
}
