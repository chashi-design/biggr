import CloudKit
import Foundation
import UIKit

/// iCloud同期状態を取得・監視するストア
@MainActor
final class ICloudSyncStatusStore: ObservableObject {
    enum Status {
        case checking
        case synced
        case localOnly
        case error
    }

    enum Availability {
        case available
        case noAccount
        case restricted
        case unknown
    }

    @Published private(set) var status: Status = .checking
    @Published private(set) var availability: Availability = .unknown
    @Published private(set) var lastUpdatedAt: Date?

    private var isObserving = false
    private var isRefreshing = false
    private var observers: [NSObjectProtocol] = []

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        let center = NotificationCenter.default

        observers.append(center.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refresh() }
        })

        observers.append(center.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refresh() }
        })
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        status = .checking
        do {
            let accountStatus = try await CKContainer.default().accountStatus()
            apply(accountStatus: accountStatus)
        } catch {
            availability = .unknown
            status = .error
        }
        lastUpdatedAt = .now
        isRefreshing = false
    }

    private func apply(accountStatus: CKAccountStatus) {
        switch accountStatus {
        case .available:
            availability = .available
            status = .synced
        case .noAccount:
            availability = .noAccount
            status = .localOnly
        case .restricted:
            availability = .restricted
            status = .localOnly
        case .couldNotDetermine:
            availability = .unknown
            status = .error
        case .temporarilyUnavailable:
            availability = .unknown
            status = .error
        @unknown default:
            availability = .unknown
            status = .error
        }
    }
}
