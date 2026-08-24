//
//  MoneyAmount.swift
//  Tally
//

import Foundation

enum MoneyAmount {
    private static let defaultCurrencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func isValidEditingText(_ input: String, locale: Locale = .current) -> Bool {
        guard !input.isEmpty else { return true }

        let decimalSeparator = locale.decimalSeparator ?? "."
        guard input.allSatisfy({ character in
            ("0"..."9").contains(character) || String(character) == decimalSeparator
        }) else {
            return false
        }

        let parts = input.components(separatedBy: decimalSeparator)
        guard parts.count <= 2 else { return false }

        let wholePart = parts[0]
        guard !wholePart.isEmpty else { return false }
        guard wholePart == "0" || wholePart.first != "0" else { return false }

        let fractionPart = parts.count == 2 ? parts[1] : ""
        return fractionPart.count <= 2
    }

    static func acceptedEditingText(
        proposed: String,
        replacing current: String,
        locale: Locale = .current
    ) -> String {
        isValidEditingText(proposed, locale: locale) ? proposed : current
    }

    static func cents(from input: String, locale: Locale = .current) -> Int64? {
        guard !input.isEmpty, isValidEditingText(input, locale: locale) else {
            return nil
        }

        let decimalSeparator = locale.decimalSeparator ?? "."
        guard !input.hasSuffix(decimalSeparator) else { return nil }

        let normalizedInput: String
        if decimalSeparator == "." {
            normalizedInput = input
        } else {
            normalizedInput = input.replacingOccurrences(of: decimalSeparator, with: ".")
        }

        let parts = normalizedInput.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }

        let wholePart = String(parts[0])
        let fractionPart = parts.count == 2 ? String(parts[1]) : ""
        guard (!wholePart.isEmpty || !fractionPart.isEmpty), fractionPart.count <= 2 else {
            return nil
        }
        guard wholePart.allSatisfy(\.isNumber), fractionPart.allSatisfy(\.isNumber) else {
            return nil
        }

        guard let whole = Int64(wholePart) else { return nil }

        let paddedFraction = fractionPart.padding(toLength: 2, withPad: "0", startingAt: 0)
        guard let fraction = Int64(paddedFraction) else { return nil }
        guard whole <= (Int64.max - fraction) / 100 else { return nil }

        let cents = whole * 100 + fraction
        return cents > 0 ? cents : nil
    }

    static func formatted(
        cents: Int64,
        locale: Locale = Locale(identifier: "zh_CN"),
        currencyCode: String = "CNY"
    ) -> String {
        let formatter: NumberFormatter
        if locale.identifier == "zh_CN", currencyCode == "CNY" {
            formatter = defaultCurrencyFormatter
        } else {
            formatter = makeCurrencyFormatter(locale: locale, currencyCode: currencyCode)
        }

        let amount = Decimal(cents) / 100
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0.00"
    }

    private static func makeCurrencyFormatter(
        locale: Locale,
        currencyCode: String
    ) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }

    static func editableText(cents: Int64, locale: Locale = .current) -> String {
        let whole = cents / 100
        let fraction = cents % 100
        guard fraction != 0 else { return String(whole) }

        let separator = locale.decimalSeparator ?? "."
        if fraction.isMultiple(of: 10) {
            return "\(whole)\(separator)\(fraction / 10)"
        }
        return "\(whole)\(separator)\(String(format: "%02lld", fraction))"
    }
}
