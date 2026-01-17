import SwiftUI
import UIKit

// 設定画面
struct SettingsView: View {
    @StateObject private var iCloudStatusStore = ICloudSyncStatusStore()
    @EnvironmentObject private var settingsStore: UserSettingsStore
    private var items: [SettingsLinkItem] {
        [
            SettingsLinkItem(
                title: strings.contactTitle,
                iconName: "questionmark.circle",
                url: URL(string: "https://forms.gle/zgHhoZLDLA7Y5Dmu6")!
            ),
            SettingsLinkItem(
                title: strings.termsTitle,
                iconName: "text.document",
                url: termsURL
            ),
            SettingsLinkItem(
                title: strings.privacyTitle,
                iconName: "lock",
                url: privacyPolicyURL
            )
        ]
    }

    @State private var selectedItem: SettingsLinkItem?
    @State private var isTutorialPresented = false
    @State private var navigationFeedbackTrigger = 0
    @State private var closeFeedbackTrigger = 0
    @State private var unitFeedbackTrigger = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    private var strings: SettingsStrings {
        SettingsStrings(isJapanese: isJapaneseLocale)
    }

    private var docsBaseURL: String {
        "https://biggrapp.com"
    }

    private var localePath: String {
        isJapaneseLocale ? "ja" : "en"
    }

    private var termsURL: URL {
        URL(string: "\(docsBaseURL)/\(localePath)/terms")!
    }

    private var privacyPolicyURL: URL {
        URL(string: "\(docsBaseURL)/\(localePath)/privacypolicy")!
    }

    var body: some View {
        List {
            iCloudSection
            unitSection
            linksSection
        }
        .contentMargins(.top, 4, for: .scrollContent)
        .listStyle(.insetGrouped)
        .navigationTitle(strings.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    closeFeedbackTrigger += 1
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.primary)
                }
                .accessibilityLabel(strings.closeLabel)
                .sensoryFeedback(.impact(weight: .light), trigger: closeFeedbackTrigger)
                .tint(.primary)
            }
        }
        .sheet(item: $selectedItem) { item in
            SafariView(url: item.url)
        }
        .fullScreenCover(isPresented: $isTutorialPresented) {
            TutorialView(isPresented: $isTutorialPresented)
        }
        .onChange(of: selectedItem) { _, newValue in
            if newValue != nil {
                navigationFeedbackTrigger += 1
            }
        }
        .onChange(of: isTutorialPresented) { _, newValue in
            if newValue {
                navigationFeedbackTrigger += 1
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: navigationFeedbackTrigger)
        .onAppear {
            iCloudStatusStore.startObserving()
        }
        .task {
            await iCloudStatusStore.refresh()
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        return version
    }

    private var weightUnitBinding: Binding<WeightUnit> {
        Binding(
            get: { settingsStore.weightUnit },
            set: { settingsStore.updateWeightUnit($0) }
        )
    }

    private var unitSection: some View {
        Section(strings.appSettingsSectionTitle) {
            Picker(selection: weightUnitBinding) {
                ForEach(WeightUnit.allCases) { unit in
                    Text(unit.unitLabel).tag(unit)
                }
            }
            label: {
                HStack(spacing: 12) {
                    Image(systemName: "dumbbell")
                        .foregroundStyle(.primary)
                        .font(.body)
                    Text(strings.weightUnitTitle)
                        .font(.body)
                }
            }
            .pickerStyle(.automatic)
            .onChange(of: settingsStore.weightUnit) { _, _ in
                unitFeedbackTrigger += 1
            }
            .sensoryFeedback(.impact(weight: .light), trigger: unitFeedbackTrigger)
        }
    }

    private var iCloudSection: some View {
        Section {
            SettingsValueRow(
                title: strings.iCloudSectionTitle,
                value: iCloudStatusText,
                iconName: iCloudStatusIconName
            )

            if let detail = iCloudDetailText {
                SettingsDetailRow(text: detail)
            }

            if let lastSync = iCloudLastSyncText {
                SettingsValueRow(
                    title: strings.iCloudLastSyncTitle,
                    value: lastSync,
                    iconName: "clock"
                )
            }

            HapticButton {
                openAppSettings()
            } label: {
                SettingsRow(title: strings.iCloudOpenSettingsTitle, iconName: "gearshape")
            }
            .buttonStyle(.plain)
        }
    }

    private var iCloudStatusText: String {
        switch iCloudStatusStore.status {
        case .synced:
            return strings.iCloudStatusSynced
        case .checking:
            return strings.iCloudStatusSyncing
        case .localOnly:
            return strings.iCloudStatusLocalOnly
        case .error:
            return strings.iCloudStatusError
        }
    }

    private var iCloudDetailText: String? {
        switch iCloudStatusStore.status {
        case .synced:
            return nil
        case .checking:
            return strings.iCloudDetailSyncing
        case .localOnly:
            return strings.iCloudDetailLocalOnly
        case .error:
            return strings.iCloudDetailError
        }
    }

    private var iCloudStatusIconName: String {
        switch iCloudStatusStore.status {
        case .synced, .checking:
            return "icloud"
        case .localOnly, .error:
            return "icloud.slash"
        }
    }

    private var iCloudLastSyncText: String? {
        guard let date = iCloudStatusStore.lastUpdatedAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = strings.locale
        formatter.dateFormat = strings.iCloudLastSyncFormat
        return formatter.string(from: date)
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private var linksSection: some View {
        Section(strings.otherSectionTitle) {
            Button {
                isTutorialPresented = true
            } label: {
                SettingsRow(title: strings.tutorialTitle, iconName: "sparkles")
            }
            .buttonStyle(.plain)

            ForEach(items) { item in
                Button {
                    selectedItem = item
                } label: {
                    SettingsRow(title: item.title, iconName: item.iconName)
                }
                .buttonStyle(.plain)
            }

            SettingsVersionRow(title: strings.versionTitle, versionText: appVersionText)
        }
    }
}

struct SettingsLinkItem: Identifiable, Hashable {
    let title: String
    let iconName: String
    let url: URL
    var id: URL { url }
}

private struct SettingsStrings {
    let isJapanese: Bool

    var locale: Locale {
        isJapanese ? Locale(identifier: "ja_JP") : Locale(identifier: "en_US")
    }

    var navigationTitle: String { isJapanese ? "設定" : "Settings" }
    var closeLabel: String { isJapanese ? "閉じる" : "Close" }
    var appSettingsSectionTitle: String { isJapanese ? "アプリ設定" : "App Settings" }
    var weightUnitTitle: String { isJapanese ? "重量の単位" : "Weight Unit" }
    var otherSectionTitle: String { isJapanese ? "その他" : "Other" }
    var versionTitle: String { isJapanese ? "バージョン" : "Version" }
    var tutorialTitle: String { isJapanese ? "チュートリアル" : "Tutorial" }
    var contactTitle: String { isJapanese ? "お問い合わせ" : "Contact" }
    var termsTitle: String { isJapanese ? "利用規約" : "Terms of Service" }
    var privacyTitle: String { isJapanese ? "プライバシーポリシー" : "Privacy Policy" }
    var iCloudSectionTitle: String { isJapanese ? "iCloud同期" : "iCloud Sync" }
    var iCloudStatusSynced: String { isJapanese ? "同期済み" : "Synced" }
    var iCloudStatusSyncing: String { isJapanese ? "同期中..." : "Syncing..." }
    var iCloudStatusLocalOnly: String { isJapanese ? "iCloud未設定" : "iCloud not available" }
    var iCloudStatusError: String { isJapanese ? "同期エラー" : "Sync error" }
    var iCloudDetailSyncing: String {
        isJapanese
            ? "最新になるまで少し時間がかかる場合があります。"
            : "It may take a moment to finish."
    }
    var iCloudDetailLocalOnly: String {
        isJapanese
            ? "この端末内にのみ保存されています。アプリ削除や機種変更でデータが消えます。iCloud設定を確認してください。"
            : "Data is stored only on this device. Uninstalling or switching devices will lose data. Check iCloud settings."
    }
    var iCloudDetailError: String {
        isJapanese
            ? "iCloudの状態を確認できませんでした。通信状態や設定を確認してください。"
            : "Couldn't check iCloud status. Please check your connection and settings."
    }
    var iCloudLastSyncTitle: String { isJapanese ? "最終同期" : "Last Sync" }
    var iCloudLastSyncFormat: String { isJapanese ? "yyyy/MM/dd HH:mm" : "MMM d, HH:mm" }
    var iCloudOpenSettingsTitle: String { isJapanese ? "設定を開く" : "Open Settings" }
}
#Preview {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(UserSettingsStore())
}
