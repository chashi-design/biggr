import SwiftData
import SwiftUI

// 保存されたトレーニング(Workout)を日付の新しい順にリスト表示する画面
struct HistoryView: View {
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            List {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "まだ記録がありません",
                        systemImage: "tray",
                        description: Text("ログでトレーニングを保存するとここに表示されます")
                    )
                } else {
                    ForEach(workouts) { workout in
                        NavigationLink {
                            WorkoutDetailView(workout: workout)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(dateTimeString(for: workout.date))
                                        .font(.headline)
                                    if !workout.note.isEmpty {
                                        Text(workout.note)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(workout.sets.count)セット")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(workout: workout)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deleteWorkouts)
                }
            }
            .navigationTitle("履歴")
        }
    }

    private func dateTimeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func delete(workout: Workout) {
        context.delete(workout)
        try? context.save()
    }

    private func deleteWorkouts(atOffsets offsets: IndexSet) {
        for index in offsets {
            guard workouts.indices.contains(index) else { continue }
            delete(workout: workouts[index])
        }
    }
}

// 1回分のトレーニング内容(セットの一覧)を表示
struct WorkoutDetailView: View {
    let workout: Workout

    var body: some View {
        List {
            Section("概要") {
                Text(dateTimeString(for: workout.date))
                if !workout.note.isEmpty {
                    Text(workout.note)
                }
            }

            Section("セット") {
                if workout.sets.isEmpty {
                    Text("セットがありません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(workout.sets) { set in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(set.exerciseName)
                                if let rpe = set.rpe {
                                    Text("RPE \(rpe, format: .number.precision(.fractionLength(1)))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("\(set.weight, format: .number.precision(.fractionLength(0...2))) kg × \(set.reps)")
                        }
                    }
                }
            }
        }
        .navigationTitle("詳細")
    }

    private func dateTimeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    HistoryView()
}
