import SwiftData
import SwiftUI

// 種目選択シート
struct ExercisePickerSheet: View {
    let exercises: [ExerciseCatalog]
    @Binding var selections: Set<String>
    var onCancel: () -> Void
    var onComplete: () -> Void
    @EnvironmentObject private var favoritesStore: ExerciseFavoritesStore
    @FocusState private var isSearchFocused: Bool
    @State private var selectedGroup: String?
    @State private var searchText: String = ""
    @State private var selectionFeedbackTrigger = 0
    @State private var searchFeedbackTrigger = 0
    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }
    private var strings: ExercisePickerStrings {
        ExercisePickerStrings(isJapanese: isJapaneseLocale)
    }

    private let muscleGroupOrder = ["chest", "shoulders", "arms", "back", "legs", "abs", "cardio"]
    private let searchGroupOrder = ["chest", "shoulders", "arms", "back", "legs", "abs", "cardio"]

    var body: some View {
        NavigationStack {
            listView
                .navigationTitle(strings.navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .applyScrollEdgeEffectStyleIfAvailable()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        HapticButton(action: onCancel) {
                            Text(strings.cancelTitle)
                                .foregroundStyle(.primary)
                        }
                        .tint(.primary)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        HapticButton {
                            onComplete()
                        } label: {
                            Label {
                                Text(strings.doneTitle)
                            } icon: {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selections.isEmpty)
                    }
                }
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: strings.searchPrompt
                )
                .searchFocused($isSearchFocused)
                .modifier(SearchToolbarVisibility())
                .onChange(of: selections) { _, newValue in
                    selectionFeedbackTrigger += 1
                }
                .onChange(of: isSearchFocused) { _, newValue in
                    searchFeedbackTrigger += 1
                }
                .onChange(of: searchText) { oldValue, newValue in
                    if !oldValue.isEmpty, newValue.isEmpty {
                        searchFeedbackTrigger += 1
                    }
                }
                .sensoryFeedback(.impact(weight: .light), trigger: selectionFeedbackTrigger)
                .sensoryFeedback(.impact(weight: .light), trigger: searchFeedbackTrigger)
        }
        .onAppear {
            selectedGroup = muscleGroups.first
        }
    }

    @ViewBuilder
    private var listView: some View {
        List {
            if !isSearchFocused, !muscleGroups.isEmpty {
                VStack(spacing: 0) {
                    Picker(strings.muscleGroupPickerTitle, selection: $selectedGroup) {
                        ForEach(muscleGroups, id: \.self) { group in
                            Text(MuscleGroupLabel.label(for: group)).tag(String?.some(group))
                        }
                    }
                    .pickerStyle(.segmented)
                    .segmentedHaptic(trigger: selectedGroup)
                    .padding(.horizontal, 0)
                    .padding(.vertical, 0)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
            if isSearchFocused {
                if !searchFavorites.isEmpty {
                    Section(strings.favoritesTitle) {
                        ForEach(searchFavorites, id: \.id) { item in
                            exerciseRow(for: item)
                        }
                    }
                }

                ForEach(searchGroupOrder, id: \.self) { group in
                    let items = searchNonFavoriteExercises(for: group)
                    if !items.isEmpty {
                        Section(searchSectionTitle(for: group)) {
                            ForEach(items, id: \.id) { item in
                                exerciseRow(for: item)
                            }
                        }
                    }
                }
            } else {
                if !filteredFavorites.isEmpty {
                    let favoriteLabel = strings.favoritesSectionTitle(
                        groupName: selectedGroup.map { MuscleGroupLabel.label(for: $0) }
                    )
                    Section(favoriteLabel) {
                        ForEach(filteredFavorites, id: \.id) { item in
                            exerciseRow(for: item)
                        }
                    }
                }

                if !filteredNonFavorites.isEmpty {
                    let groupLabel = strings.exercisesSectionTitle(
                        groupName: selectedGroup.map { MuscleGroupLabel.label(for: $0) }
                    )
                    Section(groupLabel) {
                        ForEach(filteredNonFavorites, id: \.id) { item in
                            exerciseRow(for: item)
                        }
                    }
                }
            }
        }
        .listRowSeparator(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollContentBackground(.visible)
        .applyScrollEdgeEffectStyleIfAvailable()
    }

    private var muscleGroups: [String] {
        let groups = Set(exercises.map { $0.muscleGroup })
        let ordered = muscleGroupOrder.filter { groups.contains($0) }
        let remaining = groups.subtracting(muscleGroupOrder).sorted()
        return ordered + remaining
    }

    private var filteredExercises: [ExerciseCatalog] {
        guard let group = selectedGroup else { return [] }
        let byGroup = exercises(for: group)

        let searched: [ExerciseCatalog]
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            searched = byGroup
        } else {
            let keyword = normalizedForSearch(searchText)
            searched = byGroup.filter { item in
                let name = normalizedForSearch(item.name)
                let nameEn = normalizedForSearch(item.nameEn)
                return name.contains(keyword) || nameEn.contains(keyword)
            }
        }

        return searched.sorted { $0.name < $1.name }
    }

    private var filteredFavorites: [ExerciseCatalog] {
        filteredExercises.filter { favoritesStore.favoriteIDs.contains($0.id) }
    }

    private var filteredNonFavorites: [ExerciseCatalog] {
        filteredExercises.filter { !favoritesStore.favoriteIDs.contains($0.id) }
    }

    private var favoriteExercises: [ExerciseCatalog] {
        exercises.filter { favoritesStore.favoriteIDs.contains($0.id) }
    }

    private func exercises(for group: String) -> [ExerciseCatalog] {
        exercises.filter { $0.muscleGroup == group }
    }

    private var searchSourceExercises: [ExerciseCatalog] {
        let keyword = normalizedForSearch(searchText)
        guard !keyword.isEmpty else { return exercises }
        return exercises.filter { item in
            let name = normalizedForSearch(item.name)
            let nameEn = normalizedForSearch(item.nameEn)
            return name.contains(keyword) || nameEn.contains(keyword)
        }
    }

    private var searchFavorites: [ExerciseCatalog] {
        searchSourceExercises.filter { favoritesStore.favoriteIDs.contains($0.id) }
    }

    private func searchNonFavoriteExercises(for group: String) -> [ExerciseCatalog] {
        searchSourceExercises
            .filter { $0.muscleGroup == group }
            .filter { !favoritesStore.favoriteIDs.contains($0.id) }
    }

    private func nonFavoriteExercises(for group: String) -> [ExerciseCatalog] {
        exercises(for: group).filter { !favoritesStore.favoriteIDs.contains($0.id) }
    }

    private func searchSectionTitle(for group: String) -> String {
        MuscleGroupLabel.label(for: group)
    }

    @ViewBuilder
    private func exerciseRow(for item: ExerciseCatalog) -> some View {
        let isSelected = selections.contains(item.id)
        let isJapanese = isJapaneseLocale
        Button {
            if isSelected {
                selections.remove(item.id)
            } else {
                selections.insert(item.id)
            }
        } label: {
            HStack {
                let color = muscleColor(for: item.muscleGroup)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? color : .secondary)
                    .frame(width: 20)
                VStack(alignment: .leading) {
                    Text(item.displayName(isJapanese: isJapanese))
                }
                .padding(.leading, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func muscleColor(for key: String) -> Color {
        MuscleGroupColor.color(for: key)
    }

    private func normalizedForSearch(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // カタカナ→ひらがな、全角→半角に正規化して検索精度を上げる
        let hiragana = trimmed.applyingTransform(.hiraganaToKatakana, reverse: true) ?? trimmed
        return hiragana.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? hiragana
    }
}

private struct ExercisePickerStrings {
    let isJapanese: Bool

    var navigationTitle: String { isJapanese ? "種目を選択" : "Select Exercises" }
    var cancelTitle: String { isJapanese ? "キャンセル" : "Cancel" }
    var doneTitle: String { isJapanese ? "完了" : "Done" }
    var searchPrompt: String { isJapanese ? "種目名で検索" : "Search exercises" }
    var muscleGroupPickerTitle: String { isJapanese ? "部位" : "Muscle" }
    var favoritesTitle: String { isJapanese ? "お気に入り" : "Favorites" }
    func favoritesSectionTitle(groupName: String?) -> String {
        guard let groupName else { return favoritesTitle }
        return isJapanese ? "\(groupName)のお気に入り" : "\(groupName) Favorites"
    }
    func exercisesSectionTitle(groupName: String?) -> String {
        guard let groupName else { return isJapanese ? "種目" : "Exercises" }
        return isJapanese ? "\(groupName)の種目" : "\(groupName) Exercises"
    }
}
