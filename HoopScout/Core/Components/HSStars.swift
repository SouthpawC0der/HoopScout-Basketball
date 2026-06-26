//
//  HSStars.swift
//  HoopScout
//

import SwiftUI

struct HSStars: View {
    var rating: Double
    var size: CGFloat = 12
    var color: Color = HSColors.navy

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .resizable()
                .frame(width: size, height: size)
                .foregroundColor(color)
            Text(String(format: "%.1f", rating))
                .font(.system(size: size + 1, weight: .semibold))
                .kerning(-0.1)
                .foregroundColor(HSColors.gray900)
        }
    }
}
