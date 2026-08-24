//
//  MonthPickerView.swift
//  Tally
//

import SwiftUI

struct MonthPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let calendar: Calendar
    let onSelect: (Date) -> Void

    @State private var selectedYear: Int
    @State private var selectedMonth: Int

    private let years: ClosedRange<Int>

    init(
        selectedDate: Date,
        calendar: Calendar = .autoupdatingCurrent,
        onSelect: @escaping (Date) -> Void
    ) {
        self.calendar = calendar
        self.onSelect = onSelect

        let selectedComponents = calendar.dateComponents([.year, .month], from: selectedDate)
        let currentYear = calendar.component(.year, from: .now)
        let initialYear = selectedComponents.year ?? currentYear
        let initialMonth = selectedComponents.month ?? 1

        _selectedYear = State(initialValue: initialYear)
        _selectedMonth = State(initialValue: initialMonth)
        years = (min(currentYear, initialYear) - 10)...(max(currentYear, initialYear) + 10)
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("年份", selection: $selectedYear) {
                    ForEach(years, id: \.self) { year in
                        Text("\(year)年").tag(year)
                    }
                }
                .pickerStyle(.wheel)

                Picker("月份", selection: $selectedMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text("\(month)月").tag(month)
                    }
                }
                .pickerStyle(.wheel)
            }
            .padding(.horizontal)
            .navigationTitle("选择月份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        selectMonth()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func selectMonth() {
        guard let date = calendar.date(
            from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)
        ) else {
            return
        }

        onSelect(date)
        dismiss()
    }
}

