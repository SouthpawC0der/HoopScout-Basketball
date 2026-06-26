//
//  HSChip.swift
//  HoopScout
//

import SwiftUI

struct HSChip<Icon: View>: View {
    var title: String
    var active: Bool = false
    @ViewBuilder var icon: () -> Icon
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                icon()
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .kerning(-0.1)
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(active ? HSColors.navy : Color.white)
            .foregroundColor(active ? .white : HSColors.gray900)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(active ? Color.clear : HSColors.gray200, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

extension HSChip where Icon == EmptyView {
    init(_ title: String, active: Bool = false, action: @escaping () -> Void = {}) {
        self.init(title: title, active: active, icon: { EmptyView() }, action: action)
    }
}
