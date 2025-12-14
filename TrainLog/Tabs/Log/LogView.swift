import SwiftData
import SwiftUI

// 種目・重量・レップなどを入力し、一時的にドラフトへ保持する画面
struct LogView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var viewModel = LogViewModel()
    @Query(sort: \Workout.date, order: .reverse) private var workoutsQuery: [Workout]
    private var workouts: [Workout] { workoutsQuery }
    @State private var isShowingExercisePicker = false
    @State private var selectedExerciseForEdit: DraftExerciseEntry?
    @State private var pickerSelection: String?

    var body: some View {
        NavigationStack {
            Form {
                calendarSection
                exerciseSection
            }
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(
                DragGesture().onChanged { _ in
                    hideKeyboard()
                }
            )
            .navigationTitle("トレーニングログ")
                .task {
                    await viewModel.loadExercises()
                    viewModel.syncDraftsForSelectedDate(context: context)
                }
            .sheet(isPresented: $isShowingExercisePicker) {
                ExercisePickerSheet(
                    exercises: viewModel.exercisesCatalog,
                    selection: $pickerSelection,
                    onCancel: {
                        pickerSelection = nil
                        isShowingExercisePicker = false
                    },
                    onComplete: {
                        if let selection = pickerSelection,
                           let name = viewModel.exerciseName(forID: selection) {
                            viewModel.appendExercise(name)
                        }
                        pickerSelection = nil
                        isShowingExercisePicker = false
                    }
                )
            }
            .sheet(item: $selectedExerciseForEdit) { entry in
                SetEditorSheet(viewModel: viewModel, exerciseID: entry.id)
            }
            .onChange(of: viewModel.selectedDate) {
                viewModel.syncDraftsForSelectedDate(context: context)
            }
        }
    }

    private func preparePickerSelection() {
        if pickerSelection == nil, let first = viewModel.exercisesCatalog.first {
            pickerSelection = first.id
        }
    }

    private var workoutDots: [Date: [Color]] {
        let workoutsSnapshot = workouts
        let exercisesSnapshot = viewModel.exercisesCatalog
        let dots = WorkoutDotsBuilder.dotsByDay(
            workouts: workoutsSnapshot,
            exercises: exercisesSnapshot
        )
        return dots
    }

    private var calendarSection: some View {
        LogCalendarSection(
            selectedDate: $viewModel.selectedDate,
            workoutDots: workoutDots
        )
    }

    private var exerciseSection: some View {
        Section("今回の種目") {
            addExerciseRow

            if viewModel.draftExercises.isEmpty {
                Text("追加された種目はありません。＋から追加してください。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.draftExercises) { entry in
                    Button {
                        selectedExerciseForEdit = entry
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.exerciseName)
                                    .font(.headline)
                                Text("\(entry.completedSetCount)セット")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.removeDraftExercise(id: entry.id)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var addExerciseRow: some View {
        HStack {
            Text("種目を追加")
                .fontWeight(.semibold)
            Spacer()
            Image(systemName: "plus.circle.fill")
        }
        .foregroundStyle(.tint)
        .contentShape(Rectangle())
        .onTapGesture {
            preparePickerSelection()
            isShowingExercisePicker = true
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    LogView()
}

enum WorkoutDotsBuilder {
    static func dotsByDay(
        workouts: [Workout],
        exercises: [ExerciseCatalog]
    ) -> [Date: [Color]] {
        let calendar = Calendar.current
        let exerciseLookup = Dictionary(uniqueKeysWithValues: exercises.map { ($0.name, $0.muscleGroup) })

        var buckets: [Date: Set<String>] = [:]

        for workout in workouts {
            let day = calendar.startOfDay(for: workout.date)
            var groups = workout.sets.compactMap { set in
                exerciseLookup[set.exerciseName]
            }
            if groups.isEmpty && !workout.sets.isEmpty {
                // カタログに無い種目でもドットが出るようにデフォルトグループを付与
                groups = ["other"]
            }
            guard !groups.isEmpty else { continue }

            var current = buckets[day, default: []]
            current.formUnion(groups)
            buckets[day] = current
        }

        return buckets.mapValues { groups in
            muscleOrder.compactMap { key in
                groups.contains(key) ? groupColor[key] : nil
            }
            + groups
                .filter { !muscleOrder.contains($0) }
                .compactMap { groupColor[$0] ?? groupColor["other"] }
        }
    }

    private static var groupColor: [String: Color] {
        [
            "chest": .red,
            "shoulders": .orange,
            "arms": .yellow,
            "back": .green,
            "legs": .teal,
            "abs": .indigo,
            "other": .gray
        ]
    }

    private static var muscleOrder: [String] {
        ["chest", "shoulders", "arms", "back", "legs", "abs"]
    }
}
