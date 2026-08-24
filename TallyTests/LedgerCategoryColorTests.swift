//
//  LedgerCategoryColorTests.swift
//  TallyTests
//

import XCTest
@testable import Tally

@MainActor
final class LedgerCategoryColorTests: XCTestCase {
    func testDefaultExpenseCategoriesUseTheirAssignedSystemColorRoles() {
        let expectedColors: [(String, LedgerCategoryColor)] = [
            ("expense.food", .orange),
            ("expense.shopping", .blue),
            ("expense.transportation", .cyan),
            ("expense.housing", .indigo),
            ("expense.dailyLife", .teal),
            ("expense.education", .purple),
            ("expense.relationships", .pink),
            ("expense.entertainment", .red),
            ("expense.travel", .mint),
            ("expense.medical", .green),
            ("expense.membershipCommunication", .brown),
            ("expense.repayment", .yellow)
        ]

        for (systemKey, expectedColor) in expectedColors {
            XCTAssertEqual(
                LedgerCategoryColor.systemColor(for: systemKey),
                expectedColor
            )
        }
    }

    func testCustomCategoryUsesPersistedColorAndDefaultsToBlue() {
        let custom = CurrentLedgerCategory(
            name: "宠物",
            type: .expense,
            symbolName: "pawprint",
            color: .pink,
            sortOrder: 0,
            isSystem: false
        )
        let defaultColor = CurrentLedgerCategory(
            name: "其他",
            type: .expense,
            symbolName: "star",
            sortOrder: 1,
            isSystem: false
        )

        XCTAssertEqual(LedgerCategoryColor.resolve(for: custom), .pink)
        XCTAssertEqual(LedgerCategoryColor.resolve(for: defaultColor), .blue)
    }

    func testSelectableColorsContainSystemAndExtendedColors() {
        XCTAssertEqual(
            Set(LedgerCategoryColor.selectableColors),
            Set([
                .blue, .sky, .cyan, .teal, .mint,
                .green, .lime, .yellow, .amber, .orange,
                .coral, .red, .pink, .magenta, .purple,
                .violet, .indigo, .brown
            ])
        )
        XCTAssertEqual(LedgerCategoryColor.selectableColors.count, 18)
    }
}
