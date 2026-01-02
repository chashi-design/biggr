import SwiftUI

// 種目詳細画面
struct ExerciseDetailView: View {
    let exercise: ExerciseCatalog

    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var favoritesStore: ExerciseFavoritesStore
    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }
    private var strings: ExerciseDetailStrings {
        ExerciseDetailStrings(isJapanese: isJapaneseLocale)
    }
    private var displayName: String {
        exercise.displayName(isJapanese: isJapaneseLocale)
    }

    private var isFavorite: Bool {
        favoritesStore.isFavorite(exercise.id)
    }

    var body: some View {
        List {

            Section(strings.descriptionSectionTitle) {
                Text(descriptionText)
                    .font(.body)
                    .padding(.vertical, 4)
            }

            Section(strings.muscleSectionTitle) {
                WrapTagView(tags: [muscleTag])
            }

            Section(strings.equipmentSectionTitle) {
                if let equipmentTag {
                    WrapTagView(tags: [equipmentTag])
                } else {
                    Text(strings.noInfoText)
                        .foregroundStyle(.secondary)
                }
            }

            if !exercise.aliases.isEmpty {
                Section(strings.aliasSectionTitle) {
                    WrapTagView(tags: exercise.aliases)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                HapticButton {
                    YouTubeSearch.open(query: displayName, openURL: openURL)
                } label: {
                    Label(strings.youtubeSearchTitle, systemImage: "play.rectangle")
                        .labelStyle(.iconOnly)
                }

                HapticButton {
                    favoritesStore.toggle(id: exercise.id)
                } label: {
                    Label(
                        isFavorite ? strings.removeFavoriteLabel : strings.addFavoriteLabel,
                        systemImage: isFavorite ? "star.fill" : "star"
                    )
                        .labelStyle(.iconOnly)
                }
                .tint(isFavorite ? .yellow : .primary)
            }
        }
    }

    private var descriptionText: String {
        var parts: [String] = []
        let muscle = MuscleGroupLabel.label(for: exercise.muscleGroup)
        // descJa/descEn を優先し、空なら先頭文とパターン説明(PatternInfo)をフォールバックで使用する
        let detail = isJapaneseLocale ? exercise.descJa : exercise.descEn
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            parts.append(trimmed)
        } else if let pattern = MovementPatternLabel.detail(for: exercise.pattern) {
            parts.append(strings.descriptionLead(name: displayName, muscle: muscle))
            parts.append(pattern)
        } else {
            parts.append(strings.descriptionLead(name: displayName, muscle: muscle))
            parts.append(strings.descriptionFallback)
        }
        return parts.joined(separator: "\n")
    }

    private var muscleTag: String {
        "\(MuscleGroupLabel.label(for: exercise.muscleGroup))"
    }

    private var equipmentTag: String? {
        EquipmentLabel.label(for: exercise.equipment).map { "\($0)" }
    }

}

struct WrapTagView: View {
    let tags: [String]

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.body)
            }
        }
    }
}

enum EquipmentLabel {
    static func label(for key: String) -> String? {
        if isJapaneseLocale {
            return equipmentJa[key]
        }
        return equipmentEn[key]
    }

    private static var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    private static let equipmentJa: [String: String] = [
        "barbell": "バーベル",
        "dumbbell": "ダンベル",
        "machine": "マシン",
        "cable": "ケーブル",
        "bodyweight": "自重",
        "band": "チューブ/バンド"
    ]

    private static let equipmentEn: [String: String] = [
        "barbell": "Barbell",
        "dumbbell": "Dumbbell",
        "machine": "Machine",
        "cable": "Cable",
        "bodyweight": "Bodyweight",
        "band": "Band"
    ]
}

enum MovementPatternLabel {
    static func label(for key: String) -> String? {
        if isJapaneseLocale {
            return patterns[key]?.titleJa
        }
        return patterns[key]?.titleEn
    }

    static func detail(for key: String) -> String? {
        if isJapaneseLocale {
            return patterns[key]?.descriptionJa
        }
        return patterns[key]?.descriptionEn
    }

    private struct PatternInfo {
        let titleJa: String
        let titleEn: String
        let descriptionJa: String
        let descriptionEn: String
    }

    private static var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    private static let patterns: [String: PatternInfo] = [
        "horizontal_push": PatternInfo(
            titleJa: "水平プッシュ",
            titleEn: "Horizontal Push",
            descriptionJa: "肩甲骨を安定させ、バー/ダンベルを胸の上でコントロールしながら押し出します。",
            descriptionEn: "Stabilize the scapula and press the bar/dumbbells over the chest with control."
        ),
        "vertical_push": PatternInfo(
            titleJa: "垂直プッシュ",
            titleEn: "Vertical Push",
            descriptionJa: "体幹を締めてバランスを保ち、耳の近くを通すように真上へ押し上げます。",
            descriptionEn: "Brace your core and press straight overhead, keeping the bar path close."
        ),
        "horizontal_pull": PatternInfo(
            titleJa: "水平プル",
            titleEn: "Horizontal Pull",
            descriptionJa: "肩甲骨を寄せる意識で引き、胸を張ったまま動作を行います。",
            descriptionEn: "Pull while retracting the scapula, keeping the chest open."
        ),
        "vertical_pull": PatternInfo(
            titleJa: "垂直プル",
            titleEn: "Vertical Pull",
            descriptionJa: "肘で引くイメージでバー/グリップを引き下げ、反動を抑えてコントロールします。",
            descriptionEn: "Lead with the elbows and control the pull without momentum."
        ),
        "hip_hinge": PatternInfo(
            titleJa: "ヒンジ",
            titleEn: "Hip Hinge",
            descriptionJa: "股関節を起点に上体をたたみ、背中を丸めずにお尻を引いて動作します。",
            descriptionEn: "Move from the hips, keep the back flat, and push the hips back."
        ),
        "squat": PatternInfo(
            titleJa: "スクワット",
            titleEn: "Squat",
            descriptionJa: "足裏全体で床を踏みしめ、膝と股関節を連動させて上下動します。",
            descriptionEn: "Press through the whole foot and move hips and knees together."
        ),
        "lunge": PatternInfo(
            titleJa: "ランジ",
            titleEn: "Lunge",
            descriptionJa: "前後の足でバランスをとりながら上下動し、膝が内側に入らないよう意識します。",
            descriptionEn: "Balance between front and back legs and keep the knee tracking outward."
        ),
        "carry": PatternInfo(
            titleJa: "キャリー",
            titleEn: "Carry",
            descriptionJa: "体幹を固定し、荷重を安定させたまま歩行/移動を行います。",
            descriptionEn: "Keep the core braced and walk while holding a stable load."
        ),
        "rotation": PatternInfo(
            titleJa: "ローテーション",
            titleEn: "Rotation",
            descriptionJa: "体幹を主導にツイストを行い、腰を反らせすぎないように注意します。",
            descriptionEn: "Rotate through the core and avoid excessive lumbar extension."
        )
    ]
}

private struct ExerciseDetailStrings {
    let isJapanese: Bool

    var descriptionSectionTitle: String { isJapanese ? "説明" : "Description" }
    var muscleSectionTitle: String { isJapanese ? "部位" : "Muscle" }
    var equipmentSectionTitle: String { isJapanese ? "器具" : "Equipment" }
    var aliasSectionTitle: String { isJapanese ? "別名" : "Aliases" }
    var noInfoText: String { isJapanese ? "情報なし" : "No info" }
    var youtubeSearchTitle: String { isJapanese ? "YouTubeで検索" : "Search YouTube" }
    var addFavoriteLabel: String { isJapanese ? "お気に入り" : "Add Favorite" }
    var removeFavoriteLabel: String { isJapanese ? "お気に入り解除" : "Remove Favorite" }
    var descriptionFallback: String {
        isJapanese ? "フォームや安全に注意して実施しましょう。" : "Focus on form and train safely."
    }
    func descriptionLead(name: String, muscle: String) -> String {
        isJapanese ? "\(name)は\(muscle)を主に鍛える種目です。" : "\(name) primarily targets \(muscle)."
    }
}
