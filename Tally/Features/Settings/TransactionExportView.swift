//
//  TransactionExportView.swift
//  Tally
//

import SwiftData
import SwiftUI
import UIKit

struct TransactionExportView: View {
    private struct ExportFile: Identifiable {
        let url: URL

        var id: URL { url }
    }

    private enum ExportAlert: String, Identifiable {
        case noTransactions
        case failure

        var id: Self { self }
    }

    @Environment(\.modelContext) private var modelContext

    @State private var startDate = Calendar.autoupdatingCurrent.dateInterval(
        of: .month,
        for: .now
    )?.start ?? .now
    @State private var endDate = Date.now
    @State private var exportFile: ExportFile?
    @State private var temporaryFileURL: URL?
    @State private var exportAlert: ExportAlert?

    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        Form {
            Section("时间范围") {
                DatePicker(
                    "开始日期",
                    selection: $startDate,
                    in: ...endDate,
                    displayedComponents: .date
                )

                DatePicker(
                    "结束日期",
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: .date
                )
            }
        }
        .navigationTitle("账单导出")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                exportTransactions()
            } label: {
                Label("导出账单", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .sheet(item: $exportFile, onDismiss: removeTemporaryFile) { file in
            SystemShareSheet(activityItems: [file.url])
                .ignoresSafeArea()
        }
        .alert(item: $exportAlert) { alert in
            switch alert {
            case .noTransactions:
                Alert(
                    title: Text("暂无账单"),
                    message: Text("所选日期范围内暂无账单。"),
                    dismissButton: .default(Text("好"))
                )
            case .failure:
                Alert(
                    title: Text("无法导出账单"),
                    message: Text("生成导出文件失败，请稍后重试。"),
                    dismissButton: .default(Text("好"))
                )
            }
        }
    }

    private func exportTransactions() {
        removeTemporaryFile()

        do {
            guard
                let payload = try TransactionExportService.makePayload(
                    from: startDate,
                    through: endDate,
                    in: modelContext,
                    calendar: calendar
                )
            else {
                exportAlert = .noTransactions
                return
            }

            let fileURL = try TransactionExportService.writeTemporaryFile(
                payload: payload
            )
            temporaryFileURL = fileURL
            exportFile = ExportFile(url: fileURL)
        } catch {
            exportAlert = .failure
        }
    }

    private func removeTemporaryFile() {
        exportFile = nil
        guard let temporaryFileURL else { return }
        try? FileManager.default.removeItem(at: temporaryFileURL)
        self.temporaryFileURL = nil
    }
}

private struct SystemShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}

#Preview {
    NavigationStack {
        TransactionExportView()
    }
    .modelContainer(
        for: [
            CurrentLedgerTransaction.self,
            CurrentLedgerCategory.self,
            CurrentLedgerSubcategory.self
        ],
        inMemory: true
    )
}
