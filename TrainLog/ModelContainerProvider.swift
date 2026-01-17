import CloudKit
import Foundation
import SwiftData

@MainActor
final class ModelContainerProvider: ObservableObject {
    enum StoreType {
        case local
        case cloud
    }

    static var defaultSchema: Schema {
        Schema([Workout.self, ExerciseSet.self, UserSettings.self, FavoriteExercise.self])
    }

    static var defaultCloudContainerIdentifier: String? {
        guard let bundleId = Bundle.main.bundleIdentifier else { return nil }
        return "iCloud.\(bundleId)"
    }

    let container: ModelContainer
    let storeType: StoreType

    private let schema: Schema
    private let localStoreURL: URL
    private let cloudStoreURL: URL
    private let cloudContainerIdentifier: String?
    private let migrationKey = "didMigrateLocalStoreToCloud"
    private var didStartMigration = false

    init(
        schema: Schema = ModelContainerProvider.defaultSchema,
        cloudContainerIdentifier: String? = ModelContainerProvider.defaultCloudContainerIdentifier
    ) {
        self.schema = schema
        self.cloudContainerIdentifier = cloudContainerIdentifier

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        do {
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        } catch {
            print("AppSupport directory create error:", error)
        }

        self.localStoreURL = appSupport.appendingPathComponent("TrainLog.store")
        self.cloudStoreURL = appSupport.appendingPathComponent("TrainLogCloud.store")

        let localConfig = ModelConfiguration(schema: schema, url: localStoreURL)
        let accountStatus = Self.fetchAccountStatus()
        if accountStatus == .available {
            let cloudConfig = ModelConfiguration(
                schema: schema,
                cloudKitContainerIdentifier: cloudContainerIdentifier,
                url: cloudStoreURL
            )
            do {
                container = try ModelContainer(for: schema, configurations: cloudConfig)
                storeType = .cloud
            } catch {
                print("Cloud ModelContainer error:", error)
                do {
                    container = try ModelContainer(for: schema, configurations: localConfig)
                    storeType = .local
                } catch {
                    fatalError("Local ModelContainer error: \(error)")
                }
            }
        } else {
            do {
                container = try ModelContainer(for: schema, configurations: localConfig)
                storeType = .local
            } catch {
                fatalError("Local ModelContainer error: \(error)")
            }
        }

        if storeType == .cloud {
            Task { await migrateLocalStoreToCloudIfNeeded() }
        }
    }

    func migrateLocalStoreToCloudIfNeeded() async {
        guard storeType == .cloud else { return }
        guard !didStartMigration else { return }

        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationKey) else { return }
        didStartMigration = true

        guard FileManager.default.fileExists(atPath: localStoreURL.path) else {
            defaults.set(true, forKey: migrationKey)
            return
        }

        let localConfig = ModelConfiguration(schema: schema, url: localStoreURL)
        let localContainer: ModelContainer
        do {
            localContainer = try ModelContainer(for: schema, configurations: localConfig)
        } catch {
            print("Local ModelContainer open error:", error)
            return
        }

        let localContext = ModelContext(localContainer)
        let cloudContext = ModelContext(container)

        do {
            try migrateWorkouts(localContext: localContext, cloudContext: cloudContext)
            try migrateFavorites(localContext: localContext, cloudContext: cloudContext)
            try migrateSettings(localContext: localContext, cloudContext: cloudContext)
            try cloudContext.save()
            defaults.set(true, forKey: migrationKey)
        } catch {
            print("Local to Cloud migration error:", error)
        }
    }

    private func migrateWorkouts(localContext: ModelContext, cloudContext: ModelContext) throws {
        let localWorkouts = try localContext.fetch(FetchDescriptor<Workout>())
        guard !localWorkouts.isEmpty else { return }

        let cloudWorkouts = try cloudContext.fetch(FetchDescriptor<Workout>())
        let existingWorkoutIDs = Set(cloudWorkouts.map { $0.id })

        for workout in localWorkouts where !existingWorkoutIDs.contains(workout.id) {
            let newSets: [ExerciseSet] = workout.sets.map { set in
                let newSet = ExerciseSet(
                    exerciseId: set.exerciseId,
                    weight: set.weight,
                    reps: set.reps,
                    durationSeconds: set.durationSeconds,
                    rpe: set.rpe,
                    createdAt: set.createdAt
                )
                newSet.id = set.id
                return newSet
            }
            let newWorkout = Workout(date: workout.date, note: workout.note, sets: newSets)
            newWorkout.id = workout.id
            cloudContext.insert(newWorkout)
        }
    }

    private func migrateFavorites(localContext: ModelContext, cloudContext: ModelContext) throws {
        let localFavorites = try localContext.fetch(FetchDescriptor<FavoriteExercise>())
        guard !localFavorites.isEmpty else { return }

        let cloudFavorites = try cloudContext.fetch(FetchDescriptor<FavoriteExercise>())
        let existingIDs = Set(cloudFavorites.map { $0.exerciseId })

        for favorite in localFavorites where !existingIDs.contains(favorite.exerciseId) {
            let newFavorite = FavoriteExercise(
                exerciseId: favorite.exerciseId,
                createdAt: favorite.createdAt
            )
            cloudContext.insert(newFavorite)
        }
    }

    private func migrateSettings(localContext: ModelContext, cloudContext: ModelContext) throws {
        let localSettings = try localContext.fetch(FetchDescriptor<UserSettings>())
        guard let localPrimary = localSettings.sorted(by: { $0.updatedAt > $1.updatedAt }).first else { return }

        let cloudSettings = try cloudContext.fetch(FetchDescriptor<UserSettings>())
        guard cloudSettings.isEmpty else { return }

        let newSettings = UserSettings(
            id: localPrimary.id,
            weightUnitRaw: localPrimary.weightUnitRaw,
            updatedAt: localPrimary.updatedAt
        )
        cloudContext.insert(newSettings)
    }

    private static func fetchAccountStatus(timeout: TimeInterval = 1.0) -> CKAccountStatus? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: CKAccountStatus?
        CKContainer.default().accountStatus { status, error in
            if error == nil {
                result = status
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + timeout)
        return result
    }
}
