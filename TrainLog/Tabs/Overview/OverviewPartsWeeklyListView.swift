import SwiftUI

struct WeekListItem: Identifiable, Hashable {
    var id: Date { start }
    let start: Date
    let label: String
    let volume: Double
    let muscleGroup: String
    let displayName: String
}

struct OverviewPartsWeeklyListView: View {
    let title: String
    let items: [WeekListItem]
    let workouts: [Workout]
    let exercises: [ExerciseCatalog]

    private let locale = Locale(identifier: "ja_JP")

    var body: some View {
        List {
            ForEach(items) { item in
                NavigationLink {
                    OverviewPartsWeekDetailView(
                        weekStart: item.start,
                        muscleGroup: item.muscleGroup,
                        displayName: item.displayName,
                        workouts: workouts,
                        exercises: exercises
                    )
                } label: {
                    HStack {
                        Text(item.label)
                        Spacer()
                        Text(VolumeFormatter.string(from: item.volume, locale: locale))
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
