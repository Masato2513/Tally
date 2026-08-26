//
//  TransactionExportService.swift
//  Tally
//

import Foundation
import SwiftData

struct TransactionExportPayload {
    let data: Data
    let fileName: String
    let transactionCount: Int
}

enum TransactionExportError: Error {
    case invalidDateRange
    case invalidUTF8
}

@MainActor
enum TransactionExportService {
    private static let header = ["日期", "类型", "分类", "子分类", "金额", "备注"]
    private static let utf8BOM = Data([0xEF, 0xBB, 0xBF])

    static func makePayload(
        from startDate: Date,
        through endDate: Date,
        in modelContext: ModelContext,
        calendar: Calendar = .autoupdatingCurrent
    ) throws -> TransactionExportPayload? {
        let intervalStart = calendar.startOfDay(for: startDate)
        let inclusiveEnd = calendar.startOfDay(for: endDate)
        guard intervalStart <= inclusiveEnd else {
            throw TransactionExportError.invalidDateRange
        }
        guard
            let intervalEnd = calendar.date(
                byAdding: .day,
                value: 1,
                to: inclusiveEnd
            )
        else {
            throw TransactionExportError.invalidDateRange
        }

        let predicate = #Predicate<CurrentLedgerTransaction> { transaction in
            transaction.date >= intervalStart && transaction.date < intervalEnd
        }
        let descriptor = FetchDescriptor<CurrentLedgerTransaction>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\CurrentLedgerTransaction.date),
                SortDescriptor(\CurrentLedgerTransaction.id)
            ]
        )
        let transactions = try modelContext.fetch(descriptor)
        guard !transactions.isEmpty else { return nil }

        let categories = try modelContext.fetch(
            FetchDescriptor<CurrentLedgerCategory>()
        )
        let subcategories = try modelContext.fetch(
            FetchDescriptor<CurrentLedgerSubcategory>()
        )
        let categoriesByID = Dictionary(
            uniqueKeysWithValues: categories.map { ($0.id, $0.name) }
        )
        let subcategoriesByID = Dictionary(
            uniqueKeysWithValues: subcategories.map { ($0.id, $0.name) }
        )

        let dateFormatter = makeDateFormatter(calendar: calendar)
        var lines = [csvLine(header)]
        lines.reserveCapacity(transactions.count + 1)

        for transaction in transactions {
            let subcategoryName = transaction.subcategoryID
                .flatMap { subcategoriesByID[$0] }
                ?? ""
            lines.append(
                csvLine(
                    [
                        dateFormatter.string(from: transaction.date),
                        transaction.type.title,
                        categoriesByID[transaction.categoryID] ?? "",
                        subcategoryName,
                        amountText(cents: transaction.amountInCents),
                        transaction.note
                    ]
                )
            )
        }

        guard let csvData = lines.joined(separator: "\r\n").data(using: .utf8) else {
            throw TransactionExportError.invalidUTF8
        }
        var data = utf8BOM
        data.append(csvData)

        return TransactionExportPayload(
            data: data,
            fileName: fileName(
                from: intervalStart,
                through: inclusiveEnd,
                calendar: calendar
            ),
            transactionCount: transactions.count
        )
    }

    static func writeTemporaryFile(
        payload: TransactionExportPayload,
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("TallyExports", isDirectory: true)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let fileURL = directory.appendingPathComponent(payload.fileName)
        try payload.data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private static func csvLine(_ fields: [String]) -> String {
        fields.map(escapedCSVField).joined(separator: ",")
    }

    private static func escapedCSVField(_ field: String) -> String {
        guard field.contains(where: { character in
            character == "," || character == "\"" || character == "\n" || character == "\r"
        }) else {
            return field
        }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func amountText(cents: Int64) -> String {
        let magnitude = cents.magnitude
        let whole = magnitude / 100
        let fraction = magnitude % 100
        return String(format: "%llu.%02llu", whole, fraction)
    }

    private static func makeDateFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }

    private static func fileName(
        from startDate: Date,
        through endDate: Date,
        calendar: Calendar
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyyMMdd"
        return "记账_\(formatter.string(from: startDate))-\(formatter.string(from: endDate)).csv"
    }
}
