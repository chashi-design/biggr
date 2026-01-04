import Combine
import SwiftData
import SwiftUI

@MainActor
final class LogViewModel: ObservableObject {
    @Published var selectedDate = LogDateHelper.normalized(Date())
    @Published var exercisesCatalog: [ExerciseCatalog] = []
    @Published var isLoadingExercises = true
    @Published var exerciseLoadFailed = false
    @Published var draftExercises: [DraftExerciseEntry] = []
    @Published private(set) var draftRevision: Int = 0
    private(set) var isSyncingDrafts = false

    private var draftsCache: [Date: [DraftExerciseEntry]] = [:]
    private var lastSyncedDate: Date?

    func loadExercises() async {
        isLoadingExercises = true
        exerciseLoadFailed = false
        do {
            let items = try ExerciseLoader.loadFromBundle()
            exercisesCatalog = items.sorted { $0.name < $1.name }
            isLoadingExercises = false
        } catch {
            print("exercises.json load error:", error)
            exerciseLoadFailed = true
            isLoadingExercises = false
        }
    }

    func startNewWorkout() {
        selectedDate = LogDateHelper.normalized(selectedDate)
        draftExercises.removeAll()
        draftRevision += 1
    }

    func removeDraftExercise(atOffsets indexSet: IndexSet) {
        draftExercises.remove(atOffsets: indexSet)
        draftRevision += 1
    }

    func removeDraftExercise(id: UUID) {
        draftExercises.removeAll { $0.id == id }
        draftRevision += 1
    }

    func displayName(for exerciseId: String, isJapanese: Bool) -> String {
        exercisesCatalog.displayName(forId: exerciseId, isJapanese: isJapanese)
    }

    func trackingType(for exerciseId: String) -> ExerciseTrackingType {
        exercisesCatalog.first(where: { $0.id == exerciseId })?.trackingType ?? .weightReps
    }

    func draftEntry(with id: UUID) -> DraftExerciseEntry? {
        draftExercises.first(where: { $0.id == id })
    }

    func saveWorkout(context: ModelContext, unit: WeightUnit) {
        let savedSets = buildExerciseSets(unit: unit)
        let normalizedDate = LogDateHelper.normalized(selectedDate)

        if savedSets.isEmpty {
            if let existing = findWorkout(on: normalizedDate, context: context) {
                context.delete(existing)
                do {
                    try context.save()
                    draftsCache[normalizedDate] = draftExercises
                } catch {
                    print("Workout delete error:", error)
                }
            }
            return
        }

        for set in savedSets {
            context.insert(set)
        }

        if let existing = findWorkout(on: normalizedDate, context: context) {
            existing.sets = savedSets
        } else {
            let workout = Workout(
                date: normalizedDate,
                note: "",
                sets: savedSets
            )
            context.insert(workout)
        }

        do {
            try context.save()
            draftsCache[normalizedDate] = draftExercises
        } catch {
            print("Workout save error:", error)
        }
    }

    private func findWorkout(on date: Date, context: ModelContext) -> Workout? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { workout in
                workout.date >= startOfDay && workout.date < endOfDay
            }
        )

        return try? context.fetch(descriptor).first
    }

    func syncDraftsForSelectedDate(context: ModelContext, unit: WeightUnit) {
        isSyncingDrafts = true
        defer { isSyncingDrafts = false }
        let normalizedNewDate = LogDateHelper.normalized(selectedDate)

        if let lastDate = lastSyncedDate {
            let normalizedLast = LogDateHelper.normalized(lastDate)
            draftsCache[normalizedLast] = draftExercises
        }

        if let cachedDrafts = draftsCache[normalizedNewDate] {
            draftExercises = cachedDrafts
            lastSyncedDate = normalizedNewDate
            return
        }

        if let workout = findWorkout(on: normalizedNewDate, context: context) {
            let locale = Locale.current
            let grouped = Dictionary(grouping: workout.sets, by: { $0.exerciseId })
            let mapped = grouped.map { exerciseId, sets -> DraftExerciseEntry in
                let trackingType = trackingType(for: exerciseId)
                let rows: [DraftSetRow] = sets.map { set in
                    DraftSetRow.fromSet(set, unit: unit, locale: locale, trackingType: trackingType)
                }
                var entry = DraftExerciseEntry(exerciseId: exerciseId, defaultSetCount: 0)
                entry.sets = rows
                return entry
            }

            let isJapanese = Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
            draftExercises = mapped.sorted {
                displayName(for: $0.exerciseId, isJapanese: isJapanese) < displayName(for: $1.exerciseId, isJapanese: isJapanese)
            }
        } else {
            draftExercises = []
        }

        lastSyncedDate = normalizedNewDate
    }

    func appendExercise(_ id: String, initialSetCount: Int = 1) {
        let entry = DraftExerciseEntry(exerciseId: id, defaultSetCount: initialSetCount)
        draftExercises.append(entry)
        draftRevision += 1
    }

    func addSetRow(to exerciseID: UUID) {
        guard let index = draftExercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        draftExercises[index].sets.append(DraftSetRow())
        draftRevision += 1
    }

    func removeSetRow(exerciseID: UUID, setID: UUID) {
        guard let index = draftExercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        draftExercises[index].sets.removeAll { $0.id == setID }
        draftRevision += 1
    }

    func moveDraftExercises(from source: IndexSet, to destination: Int) {
        draftExercises.move(fromOffsets: source, toOffset: destination)
        draftRevision += 1
    }

    func updateSetRow(
        exerciseID: UUID,
        setID: UUID,
        weightText: String,
        repsText: String,
        durationText: String
    ) {
        guard let exerciseIndex = draftExercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        guard let setIndex = draftExercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        draftExercises[exerciseIndex].sets[setIndex].weightText = weightText
        draftExercises[exerciseIndex].sets[setIndex].repsText = repsText
        draftExercises[exerciseIndex].sets[setIndex].durationText = durationText
        draftRevision += 1
    }

    func weightText(exerciseID: UUID, setID: UUID) -> String {
        guard let exerciseIndex = draftExercises.firstIndex(where: { $0.id == exerciseID }) else { return "" }
        guard let setIndex = draftExercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return "" }
        return draftExercises[exerciseIndex].sets[setIndex].weightText
    }

    func repsText(exerciseID: UUID, setID: UUID) -> String {
        guard let exerciseIndex = draftExercises.firstIndex(where: { $0.id == exerciseID }) else { return "" }
        guard let setIndex = draftExercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return "" }
        return draftExercises[exerciseIndex].sets[setIndex].repsText
    }

    func durationText(exerciseID: UUID, setID: UUID) -> String {
        guard let exerciseIndex = draftExercises.firstIndex(where: { $0.id == exerciseID }) else { return "" }
        guard let setIndex = draftExercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return "" }
        return draftExercises[exerciseIndex].sets[setIndex].durationText
    }

    var hasValidSets: Bool {
        draftExercises.contains { entry in
            let trackingType = trackingType(for: entry.exerciseId)
            return entry.sets.contains { $0.isValid(trackingType: trackingType) }
        }
    }

    private func buildExerciseSets(unit: WeightUnit) -> [ExerciseSet] {
        let structured = draftExercises.flatMap { entry in
            let trackingType = trackingType(for: entry.exerciseId)
            return entry.exerciseSets(unit: unit, exerciseId: entry.exerciseId, trackingType: trackingType)
        }

        return structured
    }
}

struct DraftExerciseEntry: Identifiable {
    let id = UUID()
    var exerciseId: String
    var sets: [DraftSetRow]

    init(exerciseId: String, defaultSetCount: Int = 1) {
        self.exerciseId = exerciseId
        self.sets = (0..<defaultSetCount).map { _ in DraftSetRow() }
    }

    func exerciseSets(unit: WeightUnit, exerciseId: String, trackingType: ExerciseTrackingType) -> [ExerciseSet] {
        return sets.compactMap { $0.toExerciseSet(exerciseId: exerciseId, unit: unit, trackingType: trackingType) }
    }

    func completedSetCount(trackingType: ExerciseTrackingType) -> Int {
        sets.filter { $0.isValid(trackingType: trackingType) }.count
    }
}

struct DraftSetRow: Identifiable {
    let id = UUID()
    var weightText: String = ""
    var repsText: String = ""
    var durationText: String = ""

    func toExerciseSet(exerciseId: String, unit: WeightUnit, trackingType: ExerciseTrackingType) -> ExerciseSet? {
        switch trackingType {
        case .weightReps:
            guard let weightInput = Double(weightText), let reps = Int(repsText) else { return nil }
            let weightKg = unit.kgValue(fromDisplay: weightInput)
            return ExerciseSet(exerciseId: exerciseId, weight: weightKg, reps: reps)
        case .repsOnly:
            guard let reps = Int(repsText) else { return nil }
            return ExerciseSet(exerciseId: exerciseId, weight: 0, reps: reps)
        case .durationOnly:
            guard let seconds = Self.durationSeconds(from: durationText) else { return nil }
            return ExerciseSet(exerciseId: exerciseId, weight: 0, reps: 0, durationSeconds: seconds)
        }
    }

    func isValid(trackingType: ExerciseTrackingType) -> Bool {
        switch trackingType {
        case .weightReps:
            return Double(weightText) != nil && Int(repsText) != nil
        case .repsOnly:
            return Int(repsText) != nil
        case .durationOnly:
            return Self.durationSeconds(from: durationText) != nil
        }
    }

    static func formattedWeightText(_ weight: Double, unit: WeightUnit, locale: Locale) -> String {
        unit.formattedValue(
            fromKg: weight,
            locale: locale,
            maximumFractionDigits: 3,
            usesGroupingSeparator: false
        )
    }

    static func formattedDurationText(_ seconds: Double) -> String {
        let totalMinutes = max(0, Int((seconds / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    static func formattedDurationText(hours: Int, minutes: Int) -> String {
        let safeHours = max(0, hours)
        let safeMinutes = max(0, min(59, minutes))
        return String(format: "%02d:%02d", safeHours, safeMinutes)
    }

    static func durationComponents(from text: String) -> (hours: Int, minutes: Int)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ":")
        if parts.count == 1 {
            guard let totalMinutes = Int(parts[0]), totalMinutes >= 0 else { return nil }
            return (totalMinutes / 60, totalMinutes % 60)
        }
        guard parts.count == 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]),
              hours >= 0,
              minutes >= 0,
              minutes < 60 else { return nil }
        return (hours, minutes)
    }

    static func durationSeconds(from text: String) -> Double? {
        guard let components = durationComponents(from: text) else { return nil }
        let totalMinutes = components.hours * 60 + components.minutes
        guard totalMinutes > 0 else { return nil }
        return Double(totalMinutes * 60)
    }

    static func fromSet(
        _ set: ExerciseSet,
        unit: WeightUnit,
        locale: Locale,
        trackingType: ExerciseTrackingType
    ) -> DraftSetRow {
        switch trackingType {
        case .weightReps:
            let weightText = formattedWeightText(set.weight, unit: unit, locale: locale)
            return DraftSetRow(weightText: weightText, repsText: String(set.reps))
        case .repsOnly:
            return DraftSetRow(weightText: "", repsText: String(set.reps))
        case .durationOnly:
            let seconds = set.durationSeconds ?? 0
            let text = seconds > 0 ? formattedDurationText(seconds) : ""
            return DraftSetRow(weightText: "", repsText: "", durationText: text)
        }
    }
}
