import SwiftData
import SwiftUI
import UIKit

struct ExercisePickerSheet: View {
    let exercises: [ExerciseCatalog]
    @Binding var selection: String?
    var onCancel: () -> Void
    var onComplete: () -> Void
    @State private var selectedGroup: String?

    private let muscleGroupOrder = ["chest", "shoulders", "arms", "back", "legs", "abs"]

    var body: some View {
        NavigationStack {
            listView
                .navigationTitle("種目を選択")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { onCancel() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完了") { onComplete() }
                            .disabled(selection == nil)
                    }
                }
                .safeAreaInset(edge: .top) {
                    if !muscleGroups.isEmpty {
                        VStack(spacing: 0) {
                            Picker("部位", selection: $selectedGroup) {
                                ForEach(muscleGroups, id: \.self) { group in
                                    Text(muscleGroupLabel(group)).tag(String?.some(group))
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .background(.ultraThinMaterial)
                    }
                }
        }
        .onAppear {
            if selectedGroup == nil {
                let initialGroup = muscleGroups.first
                selectedGroup = initialGroup
                if let group = initialGroup {
                    selection = firstExerciseID(for: group)
                }
            } else if selection == nil, let group = selectedGroup {
                selection = firstExerciseID(for: group)
            }
        }
        .onChange(of: selectedGroup) { _, newValue in
            if let group = newValue {
                selection = firstExerciseID(for: group)
            } else {
                selection = nil
            }
        }
    }

    @ViewBuilder
    private var listView: some View {
        List {
            ForEach(filteredExercises, id: \.id) { (item: ExerciseCatalog) in
                Button {
                    selection = item.id
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                            if !item.nameEn.isEmpty {
                                Text(item.nameEn)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if selection == item.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var muscleGroups: [String] {
        let groups = Set(exercises.map { $0.muscleGroup })
        let ordered = muscleGroupOrder.filter { groups.contains($0) }
        let remaining = groups.subtracting(muscleGroupOrder).sorted()
        return ordered + remaining
    }

    private var filteredExercises: [ExerciseCatalog] {
        guard let group = selectedGroup else { return [] }
        return exercises
            .filter { $0.muscleGroup == group }
            .sorted { $0.name < $1.name }
    }

    private func muscleGroupLabel(_ key: String) -> String {
        switch key {
        case "chest": return "胸"
        case "shoulders": return "肩"
        case "arms": return "腕"
        case "back": return "背中"
        case "legs": return "脚"
        case "abs": return "腹"
        default: return key
        }
    }

    private func firstExerciseID(for group: String) -> String? {
        filteredExercises.first(where: { $0.muscleGroup == group })?.id
    }
}

struct SetEditorSheet: View {
    @ObservedObject var viewModel: LogViewModel
    let exerciseID: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            if let entry = viewModel.draftEntry(with: exerciseID) {
                List {
                    Section(header: Text(entry.exerciseName)) {
                        ForEach(entry.sets) { set in
                            HStack {
                                TextField(
                                    "重量(kg)",
                                    text: Binding(
                                        get: { viewModel.weightText(exerciseID: exerciseID, setID: set.id) },
                                        set: { viewModel.updateSetRow(exerciseID: exerciseID, setID: set.id, weightText: $0, repsText: viewModel.repsText(exerciseID: exerciseID, setID: set.id)) }
                                    )
                                )
                                .keyboardType(.decimalPad)
                                .frame(width: 90)

                                TextField(
                                    "レップ数",
                                    text: Binding(
                                        get: { viewModel.repsText(exerciseID: exerciseID, setID: set.id) },
                                        set: { viewModel.updateSetRow(exerciseID: exerciseID, setID: set.id, weightText: viewModel.weightText(exerciseID: exerciseID, setID: set.id), repsText: $0) }
                                    )
                                )
                                .keyboardType(.numberPad)
                                .frame(width: 80)

                                Spacer()

                                Button(role: .destructive) {
                                    viewModel.removeSetRow(exerciseID: exerciseID, setID: set.id)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .disabled(entry.sets.count <= 1)
                            }
                        }

                        Button {
                            viewModel.addSetRow(to: exerciseID)
                        } label: {
                            Label("セットを追加", systemImage: "plus.circle.fill")
                        }
                    }
                }
                .navigationTitle("セット編集")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            viewModel.saveWorkout(context: context)
                            dismiss()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Text("編集対象が見つかりませんでした")
                        .foregroundStyle(.secondary)
                    Button("閉じる") { dismiss() }
                }
                .padding()
            }
        }
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
