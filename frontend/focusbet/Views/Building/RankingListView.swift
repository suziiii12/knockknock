import SwiftUI

struct RankingListView: View {
    let entries: [TerritoryEntry]
    @Binding var highlightedUser: Int?

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                let isHighlighted = highlightedUser == index

                HStack(spacing: 10) {
                    // Rank
                    ZStack {
                        if entry.rank == 1 {
                            Text("\u{1F451}")
                                .font(.system(size: 14))
                        } else {
                            Text("#\(entry.rank)")
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textMuted)
                        }
                    }
                    .frame(width: 28)

                    UserAvatar(
                        initials: entry.userInitials,
                        colorIndex: entry.colorIndex,
                        size: 28
                    )

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(entry.userName)
                                .font(.system(size: 13, weight: (entry.rank == 1 || isHighlighted) ? .semibold : .regular))
                                .foregroundStyle(
                                    isHighlighted
                                        ? AppColors.userColors[entry.colorIndex % AppColors.userColors.count]
                                        : (entry.rank == 1 ? AppColors.accent : AppColors.textPrimary)
                                )
                            if entry.isStudying {
                                Circle()
                                    .fill(AppColors.accent)
                                    .frame(width: 5, height: 5)
                            }
                        }
                        Text("\(entry.score)pts")
                            .font(AppFonts.small)
                            .foregroundStyle(AppColors.textMuted)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(entry.ownershipPercent.oneDecimal)%")
                            .font(AppFonts.caption)
                            .foregroundStyle(isHighlighted ? AppColors.textPrimary : AppColors.textSecondary)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(AppColors.bgTertiary)
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(AppColors.userColors[entry.colorIndex % AppColors.userColors.count])
                                    .frame(width: geo.size.width * entry.ownershipPercent / 100, height: 4)
                            }
                        }
                        .frame(width: 60, height: 4)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isHighlighted
                        ? AppColors.userColors[entry.colorIndex % AppColors.userColors.count].opacity(0.12)
                        : (entry.rank == 1 ? AppColors.accent.opacity(0.05) : Color.clear)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isHighlighted
                                ? AppColors.userColors[entry.colorIndex % AppColors.userColors.count].opacity(0.4)
                                : (entry.rank == 1 ? AppColors.accent.opacity(0.2) : Color.clear),
                            lineWidth: 1
                        )
                )
                .onHover { hovering in
                    highlightedUser = hovering ? index : nil
                }
            }
        }
    }
}
