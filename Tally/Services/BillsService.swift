//
//  BillsService.swift
//  Tally
//

import Foundation

enum BillsSortOrder: String, CaseIterable, Identifiable {
    case time
    case amount

    var id: Self { self }

    var title: String {
        switch self {
        case .time:
            "按时间"
        case .amount:
            "按金额"
        }
    }

    var systemImage: String {
        switch self {
        case .time:
            "clock"
        case .amount:
            "arrow.down"
        }
    }
}

enum BillsService {
    static func transactions(
        inMonthContaining date: Date,
        from transactions: [LedgerTransaction],
        sortedBy sortOrder: BillsSortOrder,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [LedgerTransaction] {
        guard let interval = CalendarIntervals.month(containing: date, calendar: calendar) else {
            return []
        }

        let monthlyTransactions = transactions.filter { interval.contains($0.date) }
        switch sortOrder {
        case .time:
            return monthlyTransactions.sorted { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date > rhs.date
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        case .amount:
            return monthlyTransactions.sorted { lhs, rhs in
                if lhs.amountInCents != rhs.amountInCents {
                    return lhs.amountInCents > rhs.amountInCents
                }
                if lhs.date != rhs.date {
                    return lhs.date > rhs.date
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        }
    }
}
