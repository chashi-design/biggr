import SwiftData
import SwiftUI

// セット編集画面
struct SetEditorView: View {
    @ObservedObject var viewModel: LogViewModel
    let exerciseID: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.weightUnit) private var weightUnit
    @Environment(\.openURL) private var openURL
    @State private var fieldHapticTrigger = 0
    @State private var addSetHapticTrigger = 0
    @State private var deleteSetHapticTrigger = 0
    @State private var isShowingDurationPicker = false
    @State private var durationPickerTargetSetID: UUID?
    @State private var durationPickerHours = 0
    @State private var durationPickerMinutes = 0
    @FocusState private var focusedField: Field?
    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }
    private var strings: SetEditorStrings {
        SetEditorStrings(isJapanese: isJapaneseLocale)
    }
    private let durationHours = Array(0...23)
    private let durationMinutes = Array(0...59)
 
    private enum Field: Hashable {
        case weight(UUID)
        case reps(UUID)
    }

    var body: some View {
        if let entry = viewModel.draftEntry(with: exerciseID) {
            let trackingType = viewModel.trackingType(for: entry.exerciseId)
            List {
                ForEach(Array(entry.sets.enumerated()), id: \.element.id) { index, set in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 19, alignment: .trailing)
                            .foregroundStyle(.secondary)

                        switch trackingType {
                        case .weightReps:
                            weightField(setID: set.id)
                            repsField(setID: set.id)
                        case .repsOnly:
                            repsField(setID: set.id)
                        case .durationOnly:
                            durationField(setID: set.id)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            viewModel.removeSetRow(exerciseID: exerciseID, setID: set.id)
                            deleteSetHapticTrigger += 1
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .disabled(entry.sets.count <= 1)
                        .sensoryFeedback(.impact(weight: .light), trigger: deleteSetHapticTrigger)
                    }
                }

                Button {
                    viewModel.addSetRow(to: exerciseID)
                    addSetHapticTrigger += 1
                } label: {
                    Label(strings.addSetTitle, systemImage: "plus.circle.fill")
                }
                .sensoryFeedback(.impact(weight: .light), trigger: addSetHapticTrigger)

                if let metrics = metrics(
                    for: entry,
                    trackingType: trackingType,
                    context: context,
                    selectedDate: viewModel.selectedDate,
                    unit: weightUnit
                ) {
                    Section(strings.trendSectionTitle(trackingType: trackingType)) {
                        ExerciseVolumeChart(
                            data: metrics.volumeChartData,
                            barColor: muscleGroupColor(for: entry),
                            animateOnAppear: false,
                            animateOnTrigger: false,
                            animationTrigger: viewModel.draftRevision,
                            yValueLabel: strings.metricValueLabel(trackingType: trackingType, unit: weightUnit.unitLabel),
                            yAxisLabel: strings.metricAxisLabel(trackingType: trackingType, unit: weightUnit.unitLabel)
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section(strings.trendSectionTitle(trackingType: trackingType)) {
                        Text(strings.volumeTrendEmptyMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .contentMargins(.top, 4, for: .scrollContent)
            .onChange(of: viewModel.draftRevision) { _, _ in
                if !viewModel.isSyncingDrafts {
                    viewModel.saveWorkout(context: context, unit: weightUnit)
                }
            }
            .onChange(of: focusedField) { _, newValue in
                if newValue != nil {
                    fieldHapticTrigger += 1
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: fieldHapticTrigger)
            .navigationTitle(displayName(for: entry.exerciseId))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HapticButton {
                        YouTubeSearch.open(query: displayName(for: entry.exerciseId), openURL: openURL)
                    } label: {
                        Label(strings.youtubeSearchTitle, systemImage: "play.rectangle")
                            .foregroundStyle(.primary)
                    }
                    .tint(.primary)
                }
            }
            .sheet(isPresented: $isShowingDurationPicker) {
                NavigationStack {
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Picker(strings.durationHourLabel, selection: $durationPickerHours) {
                                ForEach(durationHours, id: \.self) { value in
                                    Text(strings.durationHourItem(value))
                                        .monospacedDigit()
                                        .tag(value)
                                }
                            }
                            .pickerStyle(.wheel)
                            .labelsHidden()

                            Text(":")
                                .foregroundStyle(.secondary)

                            Picker(strings.durationMinuteLabel, selection: $durationPickerMinutes) {
                                ForEach(durationMinutes, id: \.self) { value in
                                    Text(strings.durationMinuteItem(value))
                                        .monospacedDigit()
                                        .tag(value)
                                }
                            }
                            .pickerStyle(.wheel)
                            .labelsHidden()
                        }
                        .frame(height: 140)
                    }
                    .padding(.horizontal, 24)
                    .navigationTitle(strings.durationPickerTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            HapticButton {
                                isShowingDurationPicker = false
                            } label: {
                                Text(strings.cancelTitle)
                                    .foregroundStyle(.primary)
                            }
                            .tint(.primary)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            HapticButton {
                                if let setID = durationPickerTargetSetID {
                                    updateDuration(setID: setID, hours: durationPickerHours, minutes: durationPickerMinutes)
                                }
                                isShowingDurationPicker = false
                            } label: {
                                Label(strings.doneTitle, systemImage: "checkmark")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        } else {
            VStack(spacing: 12) {
                Text(strings.missingEntryMessage)
                    .foregroundStyle(.secondary)
                Button(strings.closeTitle) { dismiss() }
            }
            .padding()
        }
    }
}

private struct SetMetrics {
    let volumeChartData: [(label: String, value: Double)]
}

private extension SetEditorView {
    func weightField(setID: UUID) -> some View {
        TextField(
            strings.weightPlaceholder(unit: weightUnit.unitLabel),
            text: Binding(
                get: { viewModel.weightText(exerciseID: exerciseID, setID: setID) },
                set: { viewModel.updateSetRow(
                    exerciseID: exerciseID,
                    setID: setID,
                    weightText: $0,
                    repsText: viewModel.repsText(exerciseID: exerciseID, setID: setID),
                    durationText: viewModel.durationText(exerciseID: exerciseID, setID: setID)
                ) }
            )
        )
        .keyboardType(.decimalPad)
        .focused($focusedField, equals: .weight(setID))
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(width: 110)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = .weight(setID)
        }
    }

    func repsField(setID: UUID) -> some View {
        TextField(
            strings.repsPlaceholder,
            text: Binding(
                get: { viewModel.repsText(exerciseID: exerciseID, setID: setID) },
                set: { viewModel.updateSetRow(
                    exerciseID: exerciseID,
                    setID: setID,
                    weightText: viewModel.weightText(exerciseID: exerciseID, setID: setID),
                    repsText: $0,
                    durationText: viewModel.durationText(exerciseID: exerciseID, setID: setID)
                ) }
            )
        )
        .keyboardType(.numberPad)
        .focused($focusedField, equals: .reps(setID))
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(width: 110)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = .reps(setID)
        }
    }

    func durationField(setID: UUID) -> some View {
        let displayText = viewModel.durationText(exerciseID: exerciseID, setID: setID)
        let formattedText = strings.durationDisplay(from: displayText)
        return Button {
            let components = DraftSetRow.durationComponents(from: displayText) ?? (0, 0)
            durationPickerHours = components.0
            durationPickerMinutes = components.1
            durationPickerTargetSetID = setID
            isShowingDurationPicker = true
            fieldHapticTrigger += 1
        } label: {
            Text(displayText.isEmpty ? strings.durationPlaceholder : formattedText)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(displayText.isEmpty ? .secondary : .primary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(width: 140)
        .contentShape(Rectangle())
    }

    func updateDuration(setID: UUID, hours: Int, minutes: Int) {
        let durationText = (hours > 0 || minutes > 0)
            ? DraftSetRow.formattedDurationText(hours: hours, minutes: minutes)
            : ""
        viewModel.updateSetRow(
            exerciseID: exerciseID,
            setID: setID,
            weightText: viewModel.weightText(exerciseID: exerciseID, setID: setID),
            repsText: viewModel.repsText(exerciseID: exerciseID, setID: setID),
            durationText: durationText
        )
        fieldHapticTrigger += 1
    }

    func metrics(
        for entry: DraftExerciseEntry,
        trackingType: ExerciseTrackingType,
        context: ModelContext,
        selectedDate: Date,
        unit: WeightUnit
    ) -> SetMetrics? {
        let currentMetric = currentMetricValue(for: entry, trackingType: trackingType, unit: unit)
        guard currentMetric > 0 else { return nil }

        let calendar = Calendar.appCurrent
        let normalizedDate = calendar.startOfDay(for: selectedDate)
        let history = previousMetrics(
            exerciseId: entry.exerciseId,
            before: normalizedDate,
            trackingType: trackingType,
            context: context,
            unit: unit
        )

        var data = history.map { item in
            (label: axisLabel(for: item.date), value: item.metric)
        }
        data.append((label: axisLabel(for: normalizedDate), value: currentMetric))

        return SetMetrics(volumeChartData: data)
    }

    func previousMetrics(
        exerciseId: String,
        before date: Date,
        trackingType: ExerciseTrackingType,
        context: ModelContext,
        unit: WeightUnit
    ) -> [(date: Date, metric: Double)] {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { workout in
                workout.date < date
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let workouts = (try? context.fetch(descriptor)) ?? []
        var metrics: [(date: Date, metric: Double)] = []

        for workout in workouts {
            let metric = workout.sets
                .filter { $0.exerciseId == exerciseId }
                .reduce(0.0) { total, set in
                    total + metricValue(for: set, trackingType: trackingType, unit: unit)
                }
            guard metric > 0 else { continue }
            metrics.append((date: workout.date, metric: metric))
        }

        return Array(metrics.prefix(4)).reversed()
    }

    func currentMetricValue(
        for entry: DraftExerciseEntry,
        trackingType: ExerciseTrackingType,
        unit: WeightUnit
    ) -> Double {
        switch trackingType {
        case .weightReps:
            let volume = entry.sets.compactMap { set in
                guard let weight = Double(set.weightText), let reps = Int(set.repsText) else { return nil }
                return weight * Double(reps)
            }
            .reduce(0.0, +)
            return unit.displayValue(fromKg: volume)
        case .repsOnly:
            return Double(entry.sets.compactMap { Int($0.repsText) }.reduce(0, +))
        case .durationOnly:
            let seconds = entry.sets.compactMap { DraftSetRow.durationSeconds(from: $0.durationText) }.reduce(0, +)
            return seconds / 60
        }
    }

    func metricValue(
        for set: ExerciseSet,
        trackingType: ExerciseTrackingType,
        unit: WeightUnit
    ) -> Double {
        switch trackingType {
        case .weightReps:
            return unit.displayValue(fromKg: set.weight * Double(set.reps))
        case .repsOnly:
            return Double(set.reps)
        case .durationOnly:
            return (set.durationSeconds ?? 0) / 60
        }
    }

    func axisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = strings.locale
        formatter.dateFormat = strings.axisDateFormat
        return formatter.string(from: date)
    }

    func muscleGroupColor(for entry: DraftExerciseEntry) -> Color {
        let key = viewModel.exercisesCatalog.first(where: { $0.id == entry.exerciseId })?.muscleGroup ?? "other"
        return MuscleGroupColor.color(for: key)
    }

    func displayName(for exerciseId: String) -> String {
        viewModel.displayName(for: exerciseId, isJapanese: isJapaneseLocale)
    }

}

private struct SetEditorStrings {
    let isJapanese: Bool

    var locale: Locale { isJapanese ? Locale(identifier: "ja_JP") : Locale(identifier: "en_US") }
    var repsPlaceholder: String { isJapanese ? "レップ数" : "Reps" }
    var durationPlaceholder: String { isJapanese ? "時間" : "Time" }
    var durationHourLabel: String { isJapanese ? "時間" : "Hours" }
    var durationMinuteLabel: String { isJapanese ? "分" : "Minutes" }
    var durationPickerTitle: String { isJapanese ? "時間を選択" : "Select Time" }
    var doneTitle: String { isJapanese ? "完了" : "Done" }
    var cancelTitle: String { isJapanese ? "キャンセル" : "Cancel" }
    func durationHourItem(_ value: Int) -> String {
        isJapanese ? "\(value)時間" : "\(value) h"
    }
    func durationMinuteItem(_ value: Int) -> String {
        isJapanese ? "\(value)分" : "\(value) m"
    }
    func durationDisplay(from text: String) -> String {
        guard let components = DraftSetRow.durationComponents(from: text) else { return text }
        return isJapanese
            ? "\(components.hours)時間\(components.minutes)分"
            : String(format: "%d:%02d", components.hours, components.minutes)
    }
    var addSetTitle: String { isJapanese ? "セットを追加" : "Add Set" }
    func trendSectionTitle(trackingType: ExerciseTrackingType) -> String {
        switch trackingType {
        case .weightReps:
            return isJapanese ? "筋ボリュームの推移" : "Volume Trend"
        case .repsOnly:
            return isJapanese ? "回数の推移" : "Reps Trend"
        case .durationOnly:
            return isJapanese ? "時間の推移" : "Time Trend"
        }
    }
    var volumeTrendEmptyMessage: String {
        isJapanese ? "有効なセットを入力すると指標を表示します" : "Enter valid sets to show metrics."
    }
    var missingEntryMessage: String {
        isJapanese ? "編集対象が見つかりませんでした" : "Entry not found."
    }
    var closeTitle: String { isJapanese ? "閉じる" : "Close" }
    var youtubeSearchTitle: String { isJapanese ? "YouTubeで検索" : "Search YouTube" }
    var axisDateFormat: String { "M/d" }
    func weightPlaceholder(unit: String) -> String {
        isJapanese ? "重量(\(unit))" : "Weight (\(unit))"
    }
    func volumeLabel(unit: String) -> String {
        isJapanese ? "ボリューム(\(unit))" : "Volume (\(unit))"
    }
    func metricValueLabel(trackingType: ExerciseTrackingType, unit: String) -> String {
        switch trackingType {
        case .weightReps:
            return isJapanese ? "ボリューム(\(unit))" : "Volume (\(unit))"
        case .repsOnly:
            return isJapanese ? "回数(回)" : "Reps"
        case .durationOnly:
            return isJapanese ? "時間(分)" : "Time (min)"
        }
    }
    func metricAxisLabel(trackingType: ExerciseTrackingType, unit: String) -> String {
        switch trackingType {
        case .weightReps:
            return unit
        case .repsOnly:
            return isJapanese ? "回" : "reps"
        case .durationOnly:
            return isJapanese ? "分" : "min"
        }
    }
}
