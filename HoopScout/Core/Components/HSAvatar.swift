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

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
}
