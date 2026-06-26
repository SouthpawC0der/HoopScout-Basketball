//
//  HSSkillBadge.swift
//  HoopScout
//

import SwiftUI

struct HSSkillBadge: View {
    var level: String
    var dark: Bool = false

    private var isComp: Bool { level == "Competitive" }
    private var dots: String { isComp ? "●●●" : "●●○" }

    var body: some View {
        HStack(spacing: 4) {
            Text(dots)
            Text(level.uppercased())
        }
        .font(.system(size: 10, weight: .bold))
        .kerning(0.5)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(background)
        .foregroundColor(foreground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var background: Color {
        if dark { return HSColors.court.opacity(0.22) }
        return isComp ? HSColors.navy.opacity(0.08) : HSColors.gray500.opacity(0.10)
    }

    private var foreground: Color {
        if dark { return Color(red: 1.0, green: 0.776, blue: 0.584) }
        return isComp ? HSColors.navy : HSColors.gray700
    }
}
