//
//  LedgerCategoryColor.swift
//  Tally
//

import SwiftUI

/// 一级分类共用的系统色角色，确保同一分类在不同页面保持一致。
enum LedgerCategoryColor: String, CaseIterable, Identifiable {
    case orange
    case blue
    case yellow
    case cyan
    case indigo
    case teal
    case purple
    case pink
    case red
    case mint
    case green
    case brown
    case gray

    static let selectableColors: [Self] = [
        .blue, .cyan, .teal, .green, .mint, .orange,
        .yellow, .red, .pink, .purple, .indigo, .brown
    ]

    var id: Self { self }

    static func resolve(for category: LedgerCategory?) -> Self {
        guard let category else { return .gray }
        guard category.isSystem else {
            return Self(rawValue: category.colorRawValue) ?? .blue
        }
        return systemColor(for: category.systemKey) ?? .blue
    }

    static func systemColor(for systemKey: String?) -> Self? {
        switch systemKey {
        case "expense.food":
            .orange
        case "expense.shopping":
            .blue
        case "expense.transportation":
            .cyan
        case "expense.housing":
            .indigo
        case "expense.dailyLife":
            .teal
        case "expense.education":
            .purple
        case "expense.relationships":
            .pink
        case "expense.entertainment":
            .red
        case "expense.travel":
            .mint
        case "expense.medical", "income.career":
            .green
        case "expense.membershipCommunication":
            .brown
        case "income.investment":
            .indigo
        case "income.other":
            .gray
        default:
            nil
        }
    }

    var title: String {
        switch self {
        case .blue: "蓝色"
        case .cyan: "青色"
        case .teal: "蓝绿色"
        case .green: "绿色"
        case .mint: "薄荷色"
        case .orange: "橙色"
        case .yellow: "黄色"
        case .red: "红色"
        case .pink: "粉色"
        case .purple: "紫色"
        case .indigo: "靛蓝色"
        case .brown: "棕色"
        case .gray: "灰色"
        }
    }

    var color: Color {
        switch self {
        case .orange:
            Color(uiColor: .systemOrange)
        case .blue:
            Color(uiColor: .systemBlue)
        case .yellow:
            Color(uiColor: .systemYellow)
        case .cyan:
            Color(uiColor: .systemCyan)
        case .indigo:
            Color(uiColor: .systemIndigo)
        case .teal:
            Color(uiColor: .systemTeal)
        case .purple:
            Color(uiColor: .systemPurple)
        case .pink:
            Color(uiColor: .systemPink)
        case .red:
            Color(uiColor: .systemRed)
        case .mint:
            Color(uiColor: .systemMint)
        case .green:
            Color(uiColor: .systemGreen)
        case .brown:
            Color(uiColor: .systemBrown)
        case .gray:
            Color(uiColor: .systemGray)
        }
    }
}
