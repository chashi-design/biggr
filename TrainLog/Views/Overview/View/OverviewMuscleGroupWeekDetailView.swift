import SwiftUI

// 部位ごとの週別詳細画面（曜日別のセット/ボリューム内訳）
struct OverviewMuscleGroupWeekDetailView: View {
    let weekStart: Date
    let muscleGroup: String
    let displayName: String
    let workouts: [Workout]
    let exercises: [ExerciseCatalog]

    @Environment(\.weightUnit) private var weightUnit
    private let calendar = Calendar.appCurrent
    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }
    private var strings: OverviewMuscleGroupWeekDetailStrings {
        OverviewMuscleGroupWeekDetailStrings(isJapanese: isJapaneseLocale)
    }
    private var locale: Locale { strings.locale }
    private var trackingType: ExerciseTrackingType {
        OverviewMetrics.trackingType(for: muscleGroup)
    }

    private var normalizedWeekStart: Date {
        calendar.startOfWeek(for: weekStart) ?? weekStart
    }

    private var dailySummaries: [DaySummary] {
        (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: normalizedWeekStart) else { return nil }
            return makeSummary(for: day)
        }
    }

    var body: some View {
        List {
            listContent
        }
        .contentMargins(.top, 4, for: .scrollContent)
        .navigationTitle(weekRangeLabel(for: normalizedWeekStart))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var listContent: some View {
        ForEach(dailySummaries) { summary in
            daySection(for: summary)
        }
    }

    private func daySection(for summary: DaySummary) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 20) {
                if summary.exercises.isEmpty {
                    Text(strings.noRecordText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(summary.exercises) { exercise in
                        exerciseBlock(exercise)
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

    private func exerciseBlock(_ exercise: ExerciseBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.name)
                .font(.headline.weight(.semibold))
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                setRow(index: index, set: set)
            }
        }
    }

    private func setRow(index: Int, set: ExerciseSet) -> some View {
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

    private func makeSummary(for date: Date) -> DaySummary {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start

        var exercisesSummary: [String: ExerciseSummaryBucket] = [:]
        var totals = (sets: 0, reps: 0, volume: 0.0)

        for workout in workouts where workout.date >= start && workout.date < end {
            for set in workout.sets {
                let group = OverviewMetrics.lookupMuscleGroup(for: set, exercises: exercises)
                if muscleGroup != "other" {
                    guard group == muscleGroup else { continue }
                } else {
                    guard group == "other" else { continue }
                }
                let key = OverviewMetrics.exerciseKey(for: set)
                let displayName = exercises.displayName(
                    forId: set.exerciseId,
                    isJapanese: isJapaneseLocale
                )
                if exercisesSummary[key] == nil {
                    exercisesSummary[key] = ExerciseSummaryBucket(displayName: displayName, sets: [])
                }
                exercisesSummary[key]?.sets.append(set)
                let metric = OverviewMetrics.metricValue(for: set, trackingType: trackingType)
                totals.sets += 1
                totals.reps += set.reps
                totals.volume += metric
            }
        }

        let exerciseBreakdowns = exercisesSummary
            .map { key, bucket in
                let orderedSets = bucket.sets.sorted { $0.createdAt < $1.createdAt }
                let totalVolume = orderedSets.reduce(0.0) { $0 + OverviewMetrics.metricValue(for: $1, trackingType: trackingType) }
                return ExerciseBreakdown(
                    id: key,
                    name: bucket.displayName,
                    sets: orderedSets,
                    totalVolume: totalVolume
                )
            }
            .sorted { $0.totalVolume > $1.totalVolume }

        return DaySummary(
            date: start,
            totalSets: totals.sets,
            totalVolume: totals.volume,
            totalReps: totals.reps,
            exercises: exerciseBreakdowns
        )
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

    struct DaySummary: Identifiable {
        let id = UUID()
        let date: Date
        let totalSets: Int
        let totalVolume: Double
        let totalReps: Int
        let exercises: [ExerciseBreakdown]
    }

    private struct ExerciseSummaryBucket {
        let displayName: String
        var sets: [ExerciseSet]
    }

    struct ExerciseBreakdown: Identifiable {
        let id: String
        let name: String
        let sets: [ExerciseSet]
        let totalVolume: Double
    }

}

private struct OverviewMuscleGroupWeekDetailStrings {
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
