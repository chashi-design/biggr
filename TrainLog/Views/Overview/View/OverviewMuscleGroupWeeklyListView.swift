import SwiftUI

struct WeekListItem: Identifiable, Hashable {
    var id: Date { start }
    let start: Date
    let label: String
    let volume: Double
    let muscleGroup: String
    let displayName: String
}

// 部位ごとの週別記録一覧を表示する画面
struct OverviewMuscleGroupWeeklyListView: View {
    let title: String
    let items: [WeekListItem]
    let workouts: [Workout]
    let exercises: [ExerciseCatalog]

    @Environment(\.weightUnit) private var weightUnit
    private var locale: Locale {
        let isJapanese = Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
        return isJapanese ? Locale(identifier: "ja_JP") : Locale(identifier: "en_US")
    }
    @State private var navigationFeedbackTrigger = 0
    @State private var selectedWeekItem: WeekListItem?

    var body: some View {
        List {
            ForEach(items) { item in
                Button {
                    selectedWeekItem = item
                } label: {
                    HStack {
                        Text(item.label)
                            .font(.headline)
                        Spacer()
                        let trackingType = OverviewMetrics.trackingType(for: item.muscleGroup)
                        let parts = VolumeFormatter.metricParts(
                            from: item.volume,
                            trackingType: trackingType,
                            locale: locale,
                            unit: weightUnit
                        )
                        let unitText = parts.unit.isEmpty ? "" : " \(parts.unit)"
                        ValueWithUnitText(
                            value: parts.value,
                            unit: unitText,
                            valueFont: .body,
                            unitFont: .subheadline,
                            valueColor: .secondary,
                            unitColor: .secondary
                        )
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .imageScale(.small)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .contentMargins(.top, 4, for: .scrollContent)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedWeekItem) { item in
            OverviewMuscleGroupWeekDetailView(
                weekStart: item.start,
                muscleGroup: item.muscleGroup,
                displayName: item.displayName,
                workouts: workouts,
                exercises: exercises
            )
        }
        .onChange(of: selectedWeekItem) { _, newValue in
            if newValue != nil {
                navigationFeedbackTrigger += 1
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: navigationFeedbackTrigger)
    }
}
