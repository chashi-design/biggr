import Foundation
import SwiftData
import SwiftUI

/// アプリ設定をSwiftDataで管理するストア
@MainActor
final class UserSettingsStore: ObservableObject {
    private let migrationKey = "didMigrateUserSettingsToSwiftData"

    @Published private(set) var weightUnit: WeightUnit

    private var context: ModelContext?
    private var settings: UserSettings?

    init(initialWeightUnit: WeightUnit = .kg) {
        self.weightUnit = initialWeightUnit
    }

    func bind(context: ModelContext) {
        if let current = self.context, current === context { return }
        self.context = context
        loadSettings()
    }

    func updateWeightUnit(_ unit: WeightUnit) {
        guard weightUnit != unit else { return }
        weightUnit = unit
        persistWeightUnit(unit)
    }

    private func loadSettings() {
        guard let context else { return }
        let resolved = resolveSettings(in: context)
        settings = resolved
        let rawValue = resolved?.weightUnitRaw ?? WeightUnit.kg.rawValue
        let resolvedUnit = WeightUnit(rawValue: rawValue) ?? .kg
        if resolvedUnit.rawValue != rawValue, let settings {
            settings.weightUnitRaw = resolvedUnit.rawValue
            settings.updatedAt = .now
            do {
                try context.save()
            } catch {
                print("UserSettings normalize error:", error)
            }
        }
        weightUnit = resolvedUnit
    }

    private func resolveSettings(in context: ModelContext) -> UserSettings? {
        let descriptor = FetchDescriptor<UserSettings>()
        var records = (try? context.fetch(descriptor)) ?? []
        var primary: UserSettings?

        if !records.isEmpty {
            records.sort { $0.updatedAt > $1.updatedAt }
            primary = records.removeFirst()
            for extra in records {
                context.delete(extra)
            }
        }

        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: migrationKey) {
            let legacyRaw = defaults.string(forKey: WeightUnit.storageKey)
            if primary == nil {
                let raw = legacyRaw ?? WeightUnit.kg.rawValue
                let newSettings = UserSettings(weightUnitRaw: raw, updatedAt: .now)
                context.insert(newSettings)
                primary = newSettings
            }
            defaults.set(true, forKey: migrationKey)
        }

        if primary == nil {
            let newSettings = UserSettings(weightUnitRaw: WeightUnit.kg.rawValue, updatedAt: .now)
            context.insert(newSettings)
            primary = newSettings
        }

        do {
            try context.save()
        } catch {
            print("UserSettings load error:", error)
        }

        return primary
    }

    private func persistWeightUnit(_ unit: WeightUnit) {
        guard let context else { return }

        if let settings {
            settings.weightUnitRaw = unit.rawValue
            settings.updatedAt = .now
        } else {
            let newSettings = UserSettings(weightUnitRaw: unit.rawValue, updatedAt: .now)
            context.insert(newSettings)
            settings = newSettings
        }

        do {
            try context.save()
        } catch {
            print("UserSettings save error:", error)
        }
    }
}
