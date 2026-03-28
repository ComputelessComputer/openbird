import SwiftUI
import OpenbirdKit

struct TodayView: View {
    @ObservedObject var model: AppModel
    @State private var timelineItems: [TimelineItem] = []
    @State private var isPreparingTimeline = false

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
                .frame(maxWidth: 860, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(28)
        .navigationTitle("Today")
        .task(id: timelinePreparationKey) {
            await prepareTimeline()
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

    @MainActor
    private func prepareTimeline() async {
        let journalSections = model.todayJournal?.sections ?? []
        let rawEvents = model.rawEvents.filter { ActivityEvidencePreprocessor.isMeaningful($0) }
        let groupedRawEvents = ActivityEvidencePreprocessor.groupedMeaningfulEvents(from: model.rawEvents)
        let installedApplications = model.installedApplications

        isPreparingTimeline = true

        let preparationTask = Task.detached(priority: .userInitiated) {
            let applicationsByBundleID = Dictionary(uniqueKeysWithValues: installedApplications.map {
                ($0.bundleID.lowercased(), $0)
            })

            if journalSections.isEmpty == false {
                let eventsByID = Dictionary(uniqueKeysWithValues: rawEvents.map { ($0.id, $0) })

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
        let items = await preparationTask.value

        guard Task.isCancelled == false else {
            return
        }

        timelineItems = items
        isPreparingTimeline = false
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
