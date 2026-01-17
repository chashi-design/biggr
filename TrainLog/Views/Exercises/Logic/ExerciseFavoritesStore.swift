import Combine
import Foundation
import SwiftData

/// お気に入り種目IDをSwiftDataに保存・読み書きするストア
@MainActor
final class ExerciseFavoritesStore: ObservableObject {
    private let legacyStorageKey = "favoriteExerciseIDs"
    private let migrationKey = "didMigrateFavoriteExerciseIDsToSwiftData"

    @Published private(set) var favoriteIDs: Set<String> = []

    private var context: ModelContext?

    init() {}

    func bind(context: ModelContext) {
        if let current = self.context, current === context { return }
        self.context = context
        migrateLegacyIfNeeded()
        reload()
    }

    func isFavorite(_ id: String) -> Bool {
        favoriteIDs.contains(id)
    }

    func toggle(id: String) {
        guard let context else { return }
        if let record = favoriteRecord(for: id) {
            context.delete(record)
            favoriteIDs.remove(id)
        } else {
            context.insert(FavoriteExercise(exerciseId: id))
            favoriteIDs.insert(id)
        }
        saveOrReload()
    }

    func update(_ ids: Set<String>) {
        guard let context else {
            favoriteIDs = ids
            return
        }

        let currentIDs = favoriteIDs
        let toInsert = ids.subtracting(currentIDs)
        let toDelete = currentIDs.subtracting(ids)

        for id in toInsert {
            context.insert(FavoriteExercise(exerciseId: id))
        }
        for id in toDelete {
            if let record = favoriteRecord(for: id) {
                context.delete(record)
            }
        }

        favoriteIDs = ids
        saveOrReload()
    }

    func reload() {
        guard let context else { return }
        let descriptor = FetchDescriptor<FavoriteExercise>()
        let records = (try? context.fetch(descriptor)) ?? []
        favoriteIDs = Set(records.map { $0.exerciseId })
    }

    private func favoriteRecord(for id: String) -> FavoriteExercise? {
        guard let context else { return nil }
        let targetId = id
        let descriptor = FetchDescriptor<FavoriteExercise>(
            predicate: #Predicate { record in
                record.exerciseId == targetId
            }
        )
        return try? context.fetch(descriptor).first
    }

    private func migrateLegacyIfNeeded() {
        guard let context else { return }
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationKey) else { return }

        let data = defaults.data(forKey: legacyStorageKey) ?? Data()
        let legacyIDs = Self.decode(data: data)
        guard !legacyIDs.isEmpty else {
            defaults.set(true, forKey: migrationKey)
            return
        }

        let descriptor = FetchDescriptor<FavoriteExercise>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingIDs = Set(existing.map { $0.exerciseId })
        let toInsert = legacyIDs.subtracting(existingIDs)

        for id in toInsert {
            context.insert(FavoriteExercise(exerciseId: id))
        }

        do {
            try context.save()
        } catch {
            print("FavoriteExercise migration error:", error)
        }

        defaults.set(true, forKey: migrationKey)
    }

    private func saveOrReload() {
        guard let context else { return }
        do {
            try context.save()
        } catch {
            print("FavoriteExercise save error:", error)
            reload()
        }
    }

    private static func decode(data: Data) -> Set<String> {
        guard !data.isEmpty else { return [] }
        do {
            let decoded = try JSONDecoder().decode([String].self, from: data)
            return Set(decoded)
        } catch {
            return []
        }
    }
}
