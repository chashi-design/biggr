import SwiftUI

// 種目一覧画面

struct ExerciseListView: View {
    let title: String
    let exercises: [ExerciseCatalog]

    @EnvironmentObject private var favoritesStore: ExerciseFavoritesStore

    var body: some View {
        List {
            ForEach(exercises, id: \.id) { exercise in
                NavigationLink(value: ExerciseRoute.detail(exercise)) {
                    ExerciseRow(
                        exercise: exercise,
                        isFavorite: favoritesStore.isFavorite(exercise.id)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        favoritesStore.toggle(id: exercise.id)
                    } label: {
                        Label(
                            favoritesStore.isFavorite(exercise.id) ? "お気に入り解除" : "お気に入り",
                            systemImage: favoritesStore.isFavorite(exercise.id) ? "star.slash" : "star"
                        )
                    }
                    .tint(favoritesStore.isFavorite(exercise.id) ? .gray : .yellow)
                }
            }
            if exercises.isEmpty {
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.tertiary)
                        .imageScale(.large)
                        .font(.system(size: 32, weight: .semibold))
                    Text("お気に入り種目なし")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                    Text("お気に入り登録すると、メモ入力のときに種目を簡単に選べます。カテゴリから選んで登録しましょう。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .contentMargins(.top, 4, for: .scrollContent)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ExerciseRow: View {
    let exercise: ExerciseCatalog
    let isFavorite: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.body)
            }
            Spacer()
            if isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
}


#Preview {
    NavigationStack {
        ExerciseTabView()
            .environmentObject(ExerciseFavoritesStore())

    }
}
