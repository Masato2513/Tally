//
//  LedgerTransactionType.swift
//  Tally
//

import Foundation

enum LedgerTransactionType: String, CaseIterable, Codable, Sendable {
    case expense
    case income

    var title: String {
        switch self {
        case .expense:
            "支出"
        case .income:
            "收入"
        }
    }
}

