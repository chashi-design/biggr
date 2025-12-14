import SwiftUI

struct LogCalendarSection: View {
    @Binding var selectedDate: Date
    @State private var datePickerID = UUID()
    private let calendar = Calendar.current
    private let locale = Locale(identifier: "ja_JP")

    init(selectedDate: Binding<Date>) {
        _selectedDate = selectedDate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(LogDateHelper.label(for: selectedDate), systemImage: "calendar")
                    .font(.subheadline)

                Spacer()

                Button {
                    selectToday()
                } label: {
                    Text("今日に戻す")
                        .font(.caption)
                }
            }

            DatePicker(
                "",
                selection: Binding(
                    get: { selectedDate },
                    set: { newValue in
                        selectedDate = LogDateHelper.normalized(newValue)
                    }
                ),
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .environment(\.locale, locale)
            .id(datePickerID)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private func selectToday() {
        let today = LogDateHelper.normalized(Date())
        let alreadyToday = calendar.isDate(selectedDate, inSameDayAs: today)
        selectedDate = today
        if alreadyToday {
            datePickerID = UUID()
        }
    }
}
