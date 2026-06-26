//
//  HSLivePulse.swift
//  HoopScout
//

import SwiftUI

struct HSLivePulse: View {
    var size: CGFloat = 8
    var color: Color = HSColors.live

    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .scaleEffect(pulsing ? 2.2 : 1)
                .opacity(pulsing ? 0 : 0.6)
                .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulsing)
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .onAppear { pulsing = true }
    }
}
