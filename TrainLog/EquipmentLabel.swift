import Foundation

enum EquipmentLabel {
    static func label(for key: String) -> String? {
        guard let label = labels[key] else { return nil }
        if isJapaneseLocale {
            return label.ja
        }
        return label.en
    }

    private static var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    private struct EquipmentText {
        let ja: String
        let en: String
    }

    private static let labels: [String: EquipmentText] = [
        "barbell": EquipmentText(ja: "バーベル", en: "Barbell"),
        "dumbbell": EquipmentText(ja: "ダンベル", en: "Dumbbell"),
        "machine": EquipmentText(ja: "マシン", en: "Machine"),
        "cable": EquipmentText(ja: "ケーブル", en: "Cable"),
        "bodyweight": EquipmentText(ja: "自重", en: "Bodyweight"),
        "band": EquipmentText(ja: "チューブ/バンド", en: "Band"),
        "smith": EquipmentText(ja: "スミスマシン", en: "Smith Machine"),
        "device": EquipmentText(ja: "器具", en: "Device"),
        "kettlebell": EquipmentText(ja: "ケトルベル", en: "Kettlebell"),
        "plate": EquipmentText(ja: "プレート", en: "Plate")
    ]
}
