//
//  HSLogo.swift
//  HoopScout
//

import SwiftUI

struct HSLogo: View {
    var size: CGFloat = 56
    var light: Bool = false

    var body: some View {
        Image(light ? "HSLogoLight" : "HSLogoDark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
