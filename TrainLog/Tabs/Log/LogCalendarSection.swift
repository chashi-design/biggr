import SwiftUI

// SwiftUI製カレンダー（PageTabViewStyleで隣接月がスライド表示）
struct LogCalendarSection: View {
    @Binding var selectedDate: Date
    let workoutDots: [Date: [Color]]

    @State private var months: [Date]
    @State private var selectionIndex: Int

    private let today = LogDateHelper.normalized(Date())
    private let calendar = Calendar.current
    private let locale = Locale(identifier: "ja_JP")
    private let calendarHeight: CGFloat = 420

    init(selectedDate: Binding<Date>, workoutDots: [Date: [Color]]) {
        _selectedDate = selectedDate
        self.workoutDots = workoutDots

        let start = LogCalendarSection.startOfMonth(Calendar.current, date: selectedDate.wrappedValue)
        let built = LogCalendarSection.buildMonths(
            calendar: Calendar.current,
            today: LogDateHelper.normalized(Date()),
            workoutDots: workoutDots,
            selectedMonth: start
        )
        _months = State(initialValue: built)
        _selectionIndex = State(initialValue: built.firstIndex(of: start) ?? max(built.count - 1, 0))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            monthHeader
            weekdayHeader
            pager
        }
        .padding(.vertical, 4)
        .onChange(of: selectedDate) { newValue in
            let month = LogCalendarSection.startOfMonth(calendar, date: newValue)
            ensureMonthIncluded(month)
            if let idx = months.firstIndex(of: month) {
                selectionIndex = idx
            }
        }
        .onChange(of: workoutDots.count) { _ in
            let currentMonth = months[safe: selectionIndex] ?? LogCalendarSection.startOfMonth(calendar, date: selectedDate)
            months = LogCalendarSection.buildMonths(
                calendar: calendar,
                today: today,
                workoutDots: workoutDots,
                selectedMonth: currentMonth
            )
            selectionIndex = months.firstIndex(of: currentMonth) ?? max(months.count - 1, 0)
        }
    }

    // MARK: Header
    private var monthHeader: some View {
        let month = months[safe: selectionIndex] ?? LogCalendarSection.startOfMonth(calendar, date: selectedDate)
        return HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(Color.accentColor)
            }

            Spacer()

            Text(monthTitle(for: month))
                .font(.title2.bold())

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(isNextMonthBeyondToday(month) ? Color.secondary : Color.accentColor)
            }
            .disabled(isNextMonthBeyondToday(month))
        }
        .buttonStyle(.plain)
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(Locale.japaneseWeekdayInitials, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Pager
    private var pager: some View {
        TabView(selection: $selectionIndex) {
            ForEach(months.indices, id: \.self) { idx in
                calendarPage(for: months[idx])
                    .tag(idx)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .frame(height: calendarHeight)
        .onChange(of: selectionIndex) { newValue in
            guard months.indices.contains(newValue) else { return }
            let month = months[newValue]
            if !calendar.isDate(selectedDate, equalTo: month, toGranularity: .month) {
                if let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) {
                    selectedDate = LogDateHelper.normalized(first)
                }
            }
        }
    }

    private func calendarPage(for month: Date) -> some View {
        let days = daysInMonth(month: month)
        let rows = Int(ceil(Double(days.count) / 7.0))
        let rowHeight: CGFloat = 48
        let spacing: CGFloat = 8
        let estimatedHeight = max(calendarHeight - 40, CGFloat(rows) * rowHeight + CGFloat(max(rows - 1, 0)) * spacing)

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: spacing) {
            ForEach(days.indices, id: \.self) { index in
                if let date = days[index] {
                    dayCell(for: date)
                } else {
                    Color.clear.frame(height: rowHeight)
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(minHeight: estimatedHeight)
    }

    private func dayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let dots = workoutDots[calendar.startOfDay(for: date)] ?? []

        return VStack(spacing: 6) {
            Text("\(calendar.component(.day, from: date))")
                .font(.body.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )

            HStack(spacing: 3) {
                ForEach(Array(dots.prefix(3)).indices, id: \.self) { idx in
                    Circle()
                        .fill(dots[idx])
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 10)
        }
        .frame(height: 48)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = LogDateHelper.normalized(date)
        }
    }

    // MARK: Helpers
    private func daysInMonth(month: Date) -> [Date?] {
        guard
            let range = calendar.range(of: .day, in: .month, for: month),
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }

    private func shiftMonth(by value: Int, allowFuture: Bool = true) {
        let newIndex = selectionIndex + value
        guard months.indices.contains(newIndex) else { return }
        let newMonth = months[newIndex]
        if !allowFuture && calendar.compare(newMonth, to: today, toGranularity: .month) == .orderedDescending {
            return
        }
        selectionIndex = newIndex
        if !calendar.isDate(selectedDate, equalTo: newMonth, toGranularity: .month) {
            if let first = calendar.date(from: calendar.dateComponents([.year, .month], from: newMonth)) {
                selectedDate = LogDateHelper.normalized(first)
            }
        }
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    private func isNextMonthBeyondToday(_ base: Date) -> Bool {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: base) else {
            return true
        }
        return calendar.compare(nextMonth, to: today, toGranularity: .month) == .orderedDescending
    }

    private func ensureMonthIncluded(_ month: Date) {
        if months.contains(month) { return }
        months = LogCalendarSection.buildMonths(
            calendar: calendar,
            today: today,
            workoutDots: workoutDots,
            selectedMonth: month
        )
    }

    // MARK: - Static helpers
    private static func startOfMonth(_ calendar: Calendar, date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }

    private static func buildMonths(
        calendar: Calendar,
        today: Date,
        workoutDots: [Date: [Color]],
        selectedMonth: Date
    ) -> [Date] {
        let earliestDot = workoutDots.keys.min()
        let historicalStart = calendar.date(byAdding: .year, value: -3, to: today) ?? today
        let start = min(
            historicalStart,
            earliestDot ?? historicalStart,
            selectedMonth
        )
        let startMonth = startOfMonth(calendar, date: min(start, selectedMonth))
        let endBase = max(today, selectedMonth)
        let endMonth = startOfMonth(calendar, date: endBase)

        var months: [Date] = []
        var cursor = startMonth
        while cursor <= endMonth {
            months.append(cursor)
            cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? endMonth
        }

        if !months.contains(selectedMonth) {
            months.append(selectedMonth)
            months.sort()
        }
        return months
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Locale {
    static let japaneseWeekdayInitials = ["日", "月", "火", "水", "木", "金", "土"]
}
