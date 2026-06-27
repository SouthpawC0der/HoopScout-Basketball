//
//  HSAvatar.swift
//  HoopScout
//

import SwiftUI

struct HSAvatar: View {
    var initials: String
    var colors: [Color]
    var size: CGFloat = 40
    var ring: Bool = false
    var online: Bool = false
    var photoURL: String? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let urlString = photoURL,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            fallback
                        }
                    }
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                } else {
                    fallback
                }
            }
            .overlay(
                Group {
                    if ring {
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .padding(-2)
                            .overlay(
                                Circle()
                                    .stroke(HSColors.navy, lineWidth: 1.5)
                                    .padding(-3.5)
                            )
                    }
                }
            )

            if online {
                Circle()
                    .fill(HSColors.live)
                    .frame(width: size * 0.3, height: size * 0.3)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }
        }
        .frame(width: size, height: size)
    }

    private var fallback: some View {
        Circle()
            .fill(
                LinearGradient(colors: colors,
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
            )
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundColor(.white)
                    .kerning(0.3)
            )
    }
}

extension HSAvatar {
    init(friend: HSFriend, size: CGFloat = 40, ring: Bool = false, online: Bool = false) {
        self.init(initials: friend.initials, colors: friend.avatarColors,
                  size: size, ring: ring, online: online)
    }
    init(user: HSUser, size: CGFloat = 40, ring: Bool = false, online: Bool = false) {
        self.init(initials: user.initials, colors: user.avatarColors,
                  size: size, ring: ring, online: online)
    }
    init(profile: HSUserProfile, size: CGFloat = 40, ring: Bool = false, online: Bool = false) {
        let id = profile.id ?? profile.handle
        self.init(initials: profile.initials,
                  colors: HSAvatar.paletteColors(for: id),
                  size: size, ring: ring, online: online,
                  photoURL: profile.photoURL)
    }
    init(uid: String, initials: String, size: CGFloat = 40, ring: Bool = false, online: Bool = false) {
        self.init(initials: initials,
                  colors: HSAvatar.paletteColors(for: uid),
                  size: size, ring: ring, online: online)
    }

    static func paletteColors(for key: String) -> [Color] {
        let palettes: [[Color]] = [
            [Color(red: 0.102, green: 0.212, blue: 0.365), Color(red: 0.173, green: 0.325, blue: 0.510)],
            [Color(red: 0.753, green: 0.337, blue: 0.129), Color(red: 0.867, green: 0.420, blue: 0.125)],
            [Color(red: 0.184, green: 0.522, blue: 0.353), Color(red: 0.220, green: 0.631, blue: 0.412)],
            [Color(red: 0.333, green: 0.235, blue: 0.604), Color(red: 0.502, green: 0.353, blue: 0.835)],
            [Color(red: 0.439, green: 0.141, blue: 0.349), Color(red: 0.722, green: 0.196, blue: 0.502)],
            [Color(red: 0.455, green: 0.259, blue: 0.063), Color(red: 0.718, green: 0.475, blue: 0.122)],
            [Color(red: 0.173, green: 0.325, blue: 0.510), Color(red: 0.192, green: 0.510, blue: 0.808)]
        ]
        var hasher = Hasher()
        hasher.combine(key)
        let idx = abs(hasher.finalize()) % palettes.count
        return palettes[idx]
    }
}
