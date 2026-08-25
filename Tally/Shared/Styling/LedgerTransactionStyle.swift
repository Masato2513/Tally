//
//  LedgerTransactionStyle.swift
//  Tally
//

import SwiftUI

/// 收支类型共用的语义颜色，避免账单、报表和日历分别维护不同色值。
enum LedgerTransactionStyle {
    static func amountColor(for type: LedgerTransactionType) -> Color {
        switch type {
        case .expense:
            .primary
        case .income:
            incomeColor
        }
    }

    static func reportColor(for type: LedgerTransactionType) -> Color {
        switch type {
        case .expense:
            .accentColor
        case .income:
            incomeColor
        }
    }

    static let incomeColor = Color(
        uiColor: UIColor { traits in
            switch traits.userInterfaceStyle {
            case .dark:
                UIColor(
                    red: 114 / 255,
                    green: 198 / 255,
                    blue: 165 / 255,
                    alpha: 1
                )
            default:
                UIColor(
                    red: 40 / 255,
                    green: 116 / 255,
                    blue: 90 / 255,
                    alpha: 1
                )
            }
        }
    )
}
