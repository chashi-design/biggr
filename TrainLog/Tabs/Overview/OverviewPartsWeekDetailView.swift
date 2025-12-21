import SwiftUI

// 週ごとの詳細（曜日別のセット/ボリューム内訳）
struct OverviewPartsWeekDetailView: View {
    let weekStart: Date
    let muscleGroup: String
    let displayName: String
    let workouts: [Workout]
    let exercises: [ExerciseCatalog]

    private let calendar = Calendar.appCurrent
    private let locale = Locale(identifier: "ja_JP")

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
            Section(weekRangeLabel(for: normalizedWeekStart)) {
                ForEach(dailySummaries) { summary in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(dayLabel(for: summary.date))
                            Spacer()
                            Text(VolumeFormatter.string(from: summary.totalVolume, locale: locale))
                                .font(.subheadline.weight(.semibold))
                            if summary.totalSets > 0 {
                                Text("\(summary.totalSets)セット")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if summary.exercises.isEmpty {
                            Text("記録なし")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(summary.exercises) { exercise in
                                HStack {
                                    Text(exercise.name)
                                    Spacer()
                                    Text("\(exercise.sets)セット")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Text("\(exercise.totalReps)回")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Text(VolumeFormatter.string(from: exercise.volume, locale: locale))
                                        .font(.footnote.weight(.semibold))
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(weekRangeLabel(for: normalizedWeekStart))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func makeSummary(for date: Date) -> DaySummary {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start

        var exercisesSummary: [String: (sets: Int, reps: Int, volume: Double)] = [:]

        for workout in workouts where workout.date >= start && workout.date < end {
            for set in workout.sets {
                let group = OverviewMetrics.lookupMuscleGroup(for: set.exerciseName, exercises: exercises)
                if muscleGroup != "other" {
                    guard group == muscleGroup else { continue }
                } else {
                    guard group == "other" else { continue }
                }
                var info = exercisesSummary[set.exerciseName] ?? (sets: 0, reps: 0, volume: 0)
                info.sets += 1
                info.reps += set.reps
                info.volume += set.volume
                exercisesSummary[set.exerciseName] = info
            }
        }

        let exerciseBreakdowns = exercisesSummary
            .map { key, value in
                ExerciseBreakdown(name: key, sets: value.sets, totalReps: value.reps, volume: value.volume)
            }
            .sorted { $0.volume > $1.volume }

        let totals = exercisesSummary.values.reduce(into: (sets: 0, reps: 0, volume: 0.0)) { acc, value in
            acc.sets += value.sets
            acc.reps += value.reps
            acc.volume += value.volume
        }

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
        formatter.dateFormat = "M/d"
        return "\(formatter.string(from: start))週"
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "M/d(E)"
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

    struct ExerciseBreakdown: Identifiable {
        let id = UUID()
        let name: String
        let sets: Int
        let totalReps: Int
        let volume: Double
    }
}
