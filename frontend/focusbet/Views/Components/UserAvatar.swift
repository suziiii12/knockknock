import SwiftUI

struct UserAvatar: View {
    let initials: String
    let colorIndex: Int
    var size: CGFloat = 36
    var showCrown: Bool = false

    private var color: Color {
        AppColors.userColors[colorIndex % AppColors.userColors.count]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: size, height: size)
            Circle()
                .stroke(color, lineWidth: 2)
                .frame(width: size, height: size)
            Text(initials)
                .font(.system(size: size * 0.35, weight: .semibold))
                .foregroundStyle(color)

            if showCrown {
                Text("\u{1F451}")
                    .font(.system(size: size * 0.3))
                    .offset(y: -(size / 2 + 4))
            }
        }
    }
}
