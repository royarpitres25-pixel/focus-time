import SwiftData
import SwiftUI

/// Today's completed focus minutes, then every completed session by day.
struct HistoryScreen: View {
    @Environment(FocusEngine.self) private var engine
    @Query(sort: \FocusRecord.completedAt, order: .reverse) private var records: [FocusRecord]

    private struct DayGroup: Identifiable {
        let day: Date
        let records: [FocusRecord]
        var id: Date { day }
    }

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                List {
                    Section {
                        TodaySummaryCard(totals: FocusStats.totals(on: context.date, from: records.map(\.summary)))
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }

                    if records.isEmpty {
                        Section {
                            ContentUnavailableView(
                                "No sessions yet",
                                systemImage: "timer",
                                description: Text("Finish a focus session and it will show up here.")
                            )
                            .listRowBackground(Color.clear)
                        }
                    } else {
                        ForEach(groups) { group in
                            Section {
                                ForEach(group.records) { record in
                                    HistoryRow(record: record)
                                }
                                .onDelete { offsets in
                                    engine.delete(offsets.map { group.records[$0] })
                                }
                            } header: {
                                Text(title(for: group.day, now: context.date))
                                    .font(.retroLabel(.caption))
                                    .tracking(2)
                                    .foregroundStyle(Theme.inkSoft)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(RetroBackground(accent: Theme.mustard))
            }
            .navigationTitle("History")
        }
    }

    private var groups: [DayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: records) { calendar.startOfDay(for: $0.completedAt) }
        return grouped.keys.sorted(by: >).map { DayGroup(day: $0, records: grouped[$0] ?? []) }
    }

    private func title(for day: Date, now: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(day, inSameDayAs: now) { return "TODAY" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return "YESTERDAY"
        }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased()
    }
}

struct TodaySummaryCard: View {
    let totals: DayTotals

    var body: some View {
        HStack(spacing: 18) {
            RetroStripes(axis: .vertical, thickness: 6, spacing: 4)
                .frame(width: 26, height: 96)
            VStack(alignment: .leading, spacing: 6) {
                Text("FOCUSED TODAY")
                    .font(.retroLabel())
                    .tracking(2.5)
                    .foregroundStyle(Theme.inkSoft)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(totals.minutes)")
                        .font(.system(size: 64, weight: .black, design: .serif))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text(totals.minutes == 1 ? "minute" : "minutes")
                        .font(.headline)
                        .foregroundStyle(Theme.inkSoft)
                }
                SessionDots(count: totals.sessions)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Theme.ink.opacity(0.08))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today: \(totals.minutes) minutes focused, \(totals.sessions) sessions")
    }
}

struct HistoryRow: View {
    let record: FocusRecord

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Theme.tomato)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.name)
                    .font(.headline)
                    .fontDesign(.serif)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Text("Finished \(record.completedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            Text(DurationText.short(record.duration))
                .font(.retroLabel(.subheadline))
                .foregroundStyle(Theme.ink)
        }
        .padding(.vertical, 4)
        .listRowBackground(Theme.card)
        .accessibilityElement(children: .combine)
    }
}
