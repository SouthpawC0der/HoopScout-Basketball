//
//  HSCourtImage.swift
//  HoopScout
//
//  Stylized court "photo" placeholder — gradient sky + perspective floor with court lines.
//

import SwiftUI

struct HSCourtImage: View {
    var variant: HSCourtImageVariant = .hero1
    var height: CGFloat = 140
    var cornerRadius: CGFloat = 14
    var label: String? = nil

    private struct Recipe {
        let sky: [Color]
        let floor: Color
        let lines: Color
    }

    private var recipe: Recipe {
        switch variant {
        case .hero1: return Recipe(sky: [Color(red: 0.831, green: 0.647, blue: 0.455), Color(red: 0.651, green: 0.459, blue: 0.271)],
                                   floor: Color(red: 0.545, green: 0.353, blue: 0.169),
                                   lines: Color(red: 0.953, green: 0.894, blue: 0.769))
        case .hero2: return Recipe(sky: [Color(red: 0.173, green: 0.325, blue: 0.510), Color(red: 0.102, green: 0.212, blue: 0.365)],
                                   floor: Color(red: 0.118, green: 0.173, blue: 0.290),
                                   lines: Color(red: 0.584, green: 0.702, blue: 0.843))
        case .hero3: return Recipe(sky: [Color(red: 0.910, green: 0.886, blue: 0.835), Color(red: 0.788, green: 0.749, blue: 0.659)],
                                   floor: Color(red: 0.831, green: 0.722, blue: 0.522),
                                   lines: Color(red: 0.478, green: 0.369, blue: 0.196))
        case .hero4: return Recipe(sky: [Color(red: 0.290, green: 0.333, blue: 0.408), Color(red: 0.176, green: 0.216, blue: 0.282)],
                                   floor: Color(red: 0.165, green: 0.204, blue: 0.255),
                                   lines: Color(red: 0.580, green: 0.639, blue: 0.722))
        case .hero5: return Recipe(sky: [Color(red: 0.486, green: 0.176, blue: 0.071), Color(red: 0.263, green: 0.078, blue: 0.027)],
                                   floor: Color(red: 0.353, green: 0.122, blue: 0.051),
                                   lines: Color(red: 0.910, green: 0.659, blue: 0.486))
        case .hero6: return Recipe(sky: [Color(red: 0.059, green: 0.090, blue: 0.165), Color(red: 0.008, green: 0.024, blue: 0.090)],
                                   floor: Color(red: 0.102, green: 0.122, blue: 0.180),
                                   lines: Color(red: 0.420, green: 0.498, blue: 0.659))
        case .hero7: return Recipe(sky: [Color(red: 0.231, green: 0.349, blue: 0.596), Color(red: 0.118, green: 0.227, blue: 0.373)],
                                   floor: Color(red: 0.165, green: 0.290, blue: 0.416),
                                   lines: Color(red: 0.702, green: 0.769, blue: 0.878))
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: recipe.sky, startPoint: .top, endPoint: .bottom)

            // Court floor with perspective
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    recipe.floor
                        .frame(width: w * 1.3, height: h * 0.55)
                        .rotation3DEffect(.degrees(42), axis: (x: 1, y: 0, z: 0),
                                          anchor: .bottom, perspective: 0.5)
                        .overlay(
                            ZStack {
                                // free throw lane
                                Rectangle()
                                    .stroke(recipe.lines, lineWidth: 2)
                                    .frame(width: w * 0.38, height: h * 0.30)
                                    .opacity(0.55)
                                    .offset(y: -h * 0.05)
                                // center line
                                Rectangle()
                                    .fill(recipe.lines)
                                    .frame(width: w * 1.3, height: 2)
                                    .opacity(0.55)
                                    .offset(y: -h * 0.18)
                                // free-throw circle
                                Circle()
                                    .stroke(recipe.lines, lineWidth: 2)
                                    .frame(width: 60, height: 60)
                                    .opacity(0.55)
                                    .offset(y: h * 0.05)
                            }
                                .rotation3DEffect(.degrees(42), axis: (x: 1, y: 0, z: 0),
                                                  anchor: .bottom, perspective: 0.5)
                        )
                        .position(x: w / 2, y: h * 0.77)
                }

                // backboard
                Rectangle()
                    .fill(recipe.lines)
                    .frame(width: 34, height: 22)
                    .opacity(0.7)
                    .cornerRadius(2)
                    .overlay(
                        Rectangle()
                            .stroke(HSColors.court, lineWidth: 2)
                            .frame(width: 14, height: 10)
                            .offset(y: 16)
                    )
                    .position(x: w / 2, y: h * 0.30)

                // bottom vignette
                LinearGradient(colors: [.clear, Color.black.opacity(0.25)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(width: w, height: h)
            }

            if let label = label {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.4)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.55))
                    .cornerRadius(6)
                    .padding(10)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
