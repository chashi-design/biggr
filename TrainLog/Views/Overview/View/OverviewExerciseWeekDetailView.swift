import SwiftUI

// 種目の週詳細（週内7日分のセット一覧）を表示する画面
struct OverviewExerciseWeekDetailView: View {
    let weekStart: Date
    let exerciseId: String
    let displayName: String
    let trackingType: ExerciseTrackingType
    let workouts: [Workout]

    @Environment(\.weightUnit) private var weightUnit
    private let calendar = Calendar.appCurrent
    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }
    private var strings: OverviewExerciseWeekDetailStrings {
        OverviewExerciseWeekDetailStrings(isJapanese: isJapaneseLocale)
    }
    private var locale: Locale { strings.locale }

    private var normalizedWeekStart: Date {
        calendar.startOfWeek(for: weekStart) ?? weekStart
    }

    private var dailySummaries: [ExerciseDaySummary] {
        (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: normalizedWeekStart) else { return nil }
            return makeSummary(for: day)
        }
    }

    var body: some View {
        List {
            ForEach(dailySummaries) { summary in
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        if summary.sets.isEmpty {
                            Text(strings.noRecordText)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(summary.sets.enumerated()), id: \.element.id) { index, set in
                                HStack(spacing: 32) {
                                    Text(strings.setNumberText(index + 1))
                                    Spacer()
                                    switch trackingType {
                                    case .weightReps:
                                        if set.weight > 0 {
                                            let parts = VolumeFormatter.weightParts(from: set.weight, locale: locale, unit: weightUnit)
                                            ValueWithUnitText(
                                                value: parts.value,
                                                unit: parts.unit,
                                                valueFont: .subheadline,
                                                unitFont: .caption,
                                                valueColor: .secondary,
                                                unitColor: .secondary
                                            )
                                        }
                                        Text(strings.repsText(set.reps))
                                    case .repsOnly:
                                        Text(strings.repsText(set.reps))
                                    case .durationOnly:
                                        let duration = VolumeFormatter.durationString(from: set.durationSeconds ?? 0)
                                        Text(strings.durationText(duration))
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } header: {
                    Text(dayLabel(for: summary.date))
                        .font(.headline)
                }
            }
        }
        .contentMargins(.top, 4, for: .scrollContent)
        .navigationTitle("\(displayName) · \(weekRangeLabel(for: normalizedWeekStart))")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func makeSummary(for date: Date) -> ExerciseDaySummary {
        let sets = OverviewMetrics.sets(
            for: exerciseId,
            on: date,
            workouts: workouts,
            calendar: calendar
        )
        let totalVolume = sets.reduce(0.0) { $0 + $1.volume }
        return ExerciseDaySummary(date: date, sets: sets, totalVolume: totalVolume)
    }

    private func weekRangeLabel(for date: Date) -> String {
        let start = calendar.startOfWeek(for: date) ?? date
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = strings.weekRangeDateFormat
        return strings.weekRangeLabel(base: formatter.string(from: start))
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = strings.dayLabelDateFormat
        return formatter.string(from: date)
    }
}

struct ExerciseDaySummary: Identifiable {
    let id = UUID()
    let date: Date
    let sets: [ExerciseSet]
    let totalVolume: Double
}

private struct OverviewExerciseWeekDetailStrings {
    let isJapanese: Bool

    var locale: Locale { isJapanese ? Locale(identifier: "ja_JP") : Locale(identifier: "en_US") }
    var noRecordText: String { isJapanese ? "記録がありません" : "No records." }
    var weekRangeDateFormat: String { isJapanese ? "yyyy年MM月dd日" : "MMM d, yyyy" }
    var dayLabelDateFormat: String { isJapanese ? "yyyy年MM月dd日 E曜日" : "EEE, MMM d, yyyy" }
    func weekRangeLabel(base: String) -> String {
        isJapanese ? "\(base)週" : "Week of \(base)"
    }
    func setNumberText(_ index: Int) -> String {
        isJapanese ? "\(index)セット目" : "Set \(index)"
    }
    func repsText(_ reps: Int) -> String {
        isJapanese ? "\(reps)回" : "\(reps) reps"
    }
    func durationText(_ duration: String) -> String {
        duration
    }
}
