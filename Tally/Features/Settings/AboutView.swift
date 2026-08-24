//
//  AboutView.swift
//  Tally
//

import SwiftUI
import UIKit

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    appIcon

                    Text("记账")
                        .font(.title2.bold())

                    Text("简单、干净的私人账本")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .accessibilityElement(children: .combine)
            }

            Section("版本") {
                Text(Self.appVersion)
                    .monospacedDigit()
            }

            Section("隐私与数据") {
                Text(
                    "无需注册账号，核心功能完全离线可用。\n"
                        + "账单、分类及相关数据均保存在当前设备本地。"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let image = Self.appIconImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.accentColor)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "book.closed.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)
        }
    }

    private static let appVersion = Bundle.main.object(
        forInfoDictionaryKey: "CFBundleShortVersionString"
    ) as? String ?? "—"

    private static let appIconImage: UIImage? = {
        let dictionaryKeys = ["CFBundleIcons", "CFBundleIcons~ipad"]

        for dictionaryKey in dictionaryKeys {
            guard
                let icons = Bundle.main.object(forInfoDictionaryKey: dictionaryKey)
                    as? [String: Any],
                let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
                let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String]
            else {
                continue
            }

            for filename in iconFiles.reversed() {
                if let image = UIImage(named: filename) {
                    return image
                }
            }
        }

        return nil
    }()
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
