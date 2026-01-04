import Foundation

enum MuscleGroupLabel {
    static func label(for key: String) -> String {
        if isJapaneseLocale {
            return labelsJa[key, default: key]
        }
        return labelsEn[key, default: key]
    }

    private static var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    private static let labelsJa: [String: String] = [
        "favorites": "登録",
        "chest": "胸",
        "back": "背中",
        "shoulders": "肩",
        "arms": "腕",
        "legs": "脚",
        "abs": "体幹",
        "cardio": "有酸素",
        "other": "その他"
    ]

    private static let labelsEn: [String: String] = [
        "favorites": "Favorites",
        "chest": "Chest",
        "back": "Back",
        "shoulders": "Shoulders",
        "arms": "Arms",
        "legs": "Legs",
        "abs": "Core",
        "cardio": "Cardio",
        "other": "Other"
    ]
}
