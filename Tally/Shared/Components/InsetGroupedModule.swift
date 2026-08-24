//
//  InsetGroupedModule.swift
//  Tally
//

import SwiftUI

private struct InsetGroupedModuleModifier: ViewModifier {
    let contentPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(contentPadding)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
    }
}

extension View {
    func insetGroupedModule(contentPadding: CGFloat = 16) -> some View {
        modifier(InsetGroupedModuleModifier(contentPadding: contentPadding))
    }
}
