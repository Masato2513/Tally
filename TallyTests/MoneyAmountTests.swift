//
//  MoneyAmountTests.swift
//  TallyTests
//

import XCTest
@testable import Tally

final class MoneyAmountTests: XCTestCase {
    func testAcceptsOnlyValidEditingStates() {
        let locale = Locale(identifier: "zh_CN")

        XCTAssertTrue(MoneyAmount.isValidEditingText("", locale: locale))
        XCTAssertTrue(MoneyAmount.isValidEditingText("0", locale: locale))
        XCTAssertTrue(MoneyAmount.isValidEditingText("12.", locale: locale))
        XCTAssertTrue(MoneyAmount.isValidEditingText("12.34", locale: locale))
        XCTAssertFalse(MoneyAmount.isValidEditingText("00", locale: locale))
        XCTAssertFalse(MoneyAmount.isValidEditingText("0012", locale: locale))
        XCTAssertFalse(MoneyAmount.isValidEditingText("025", locale: locale))
        XCTAssertFalse(MoneyAmount.isValidEditingText(".", locale: locale))
        XCTAssertFalse(MoneyAmount.isValidEditingText(".5", locale: locale))
    }

    func testRejectsInvalidCharactersExtraSeparatorsAndPrecision() {
        let locale = Locale(identifier: "zh_CN")

        XCTAssertFalse(MoneyAmount.isValidEditingText("12a", locale: locale))
        XCTAssertFalse(MoneyAmount.isValidEditingText("-1", locale: locale))
        XCTAssertFalse(MoneyAmount.isValidEditingText(" 1", locale: locale))
        XCTAssertFalse(MoneyAmount.isValidEditingText("1..2", locale: locale))
        XCTAssertFalse(MoneyAmount.isValidEditingText("1.234", locale: locale))
        XCTAssertFalse(MoneyAmount.isValidEditingText("１２", locale: locale))
    }

    func testEditingConstraintUsesTheLocalesDecimalSeparator() {
        let locale = Locale(identifier: "de_DE")

        XCTAssertTrue(MoneyAmount.isValidEditingText("12,34", locale: locale))
        XCTAssertFalse(MoneyAmount.isValidEditingText("12.34", locale: locale))
        XCTAssertFalse(MoneyAmount.isValidEditingText("12,345", locale: locale))
    }

    func testParsesWholeAndDecimalAmountsExactly() {
        let locale = Locale(identifier: "zh_CN")

        XCTAssertEqual(MoneyAmount.cents(from: "28", locale: locale), 2_800)
        XCTAssertEqual(MoneyAmount.cents(from: "28.3", locale: locale), 2_830)
        XCTAssertEqual(MoneyAmount.cents(from: "28.35", locale: locale), 2_835)
        XCTAssertEqual(MoneyAmount.cents(from: "0.5", locale: locale), 50)
    }

    func testInputSequenceKeepsOnlyAcceptedEditingStates() {
        let locale = Locale(identifier: "zh_CN")

        XCTAssertEqual(typedText("025", locale: locale), "0")
        XCTAssertEqual(typedText("25.5.5.56.", locale: locale), "25.55")
        XCTAssertEqual(typedText("00.85.02", locale: locale), "0.85")
    }

    func testRejectsAnInvalidPasteWithoutChangingTheCurrentText() {
        let locale = Locale(identifier: "zh_CN")

        XCTAssertEqual(
            MoneyAmount.acceptedEditingText(
                proposed: "25.5.5.56.",
                replacing: "25.5",
                locale: locale
            ),
            "25.5"
        )
    }

    func testSupportsTheLocalesDecimalSeparator() {
        XCTAssertEqual(
            MoneyAmount.cents(from: "12,50", locale: Locale(identifier: "de_DE")),
            1_250
        )
    }

    func testRejectsInvalidZeroNegativeAndOverPreciseAmounts() {
        let locale = Locale(identifier: "zh_CN")

        XCTAssertNil(MoneyAmount.cents(from: "", locale: locale))
        XCTAssertNil(MoneyAmount.cents(from: "0", locale: locale))
        XCTAssertNil(MoneyAmount.cents(from: "-1", locale: locale))
        XCTAssertNil(MoneyAmount.cents(from: "1.234", locale: locale))
        XCTAssertNil(MoneyAmount.cents(from: "1..2", locale: locale))
        XCTAssertNil(MoneyAmount.cents(from: "025", locale: locale))
        XCTAssertNil(MoneyAmount.cents(from: "00.85", locale: locale))
        XCTAssertNil(MoneyAmount.cents(from: "12.", locale: locale))
        XCTAssertNil(MoneyAmount.cents(from: "92233720368547759", locale: locale))
    }

    func testFilterAmountParserAllowsZeroWithTheSameEditingRules() {
        XCTAssertEqual(MoneyAmount.centsAllowingZero(from: "0"), 0)
        XCTAssertEqual(MoneyAmount.centsAllowingZero(from: "0.00"), 0)
        XCTAssertEqual(MoneyAmount.centsAllowingZero(from: "25.4"), 2_540)
        XCTAssertNil(MoneyAmount.centsAllowingZero(from: "00"))
        XCTAssertNil(MoneyAmount.centsAllowingZero(from: "1.234"))
        XCTAssertNil(MoneyAmount.centsAllowingZero(from: "1.2.3"))
    }

    func testCreatesEditableTextWithoutCurrencySymbolsOrRedundantZeros() {
        let chineseLocale = Locale(identifier: "zh_CN")
        let germanLocale = Locale(identifier: "de_DE")

        XCTAssertEqual(MoneyAmount.editableText(cents: 2_800, locale: chineseLocale), "28")
        XCTAssertEqual(MoneyAmount.editableText(cents: 2_830, locale: chineseLocale), "28.3")
        XCTAssertEqual(MoneyAmount.editableText(cents: 2_835, locale: chineseLocale), "28.35")
        XCTAssertEqual(MoneyAmount.editableText(cents: 1_250, locale: germanLocale), "12,5")
    }

    private func typedText(_ input: String, locale: Locale) -> String {
        input.reduce(into: "") { current, character in
            current = MoneyAmount.acceptedEditingText(
                proposed: current + String(character),
                replacing: current,
                locale: locale
            )
        }
    }
}
