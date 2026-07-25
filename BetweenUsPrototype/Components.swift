import SwiftUI

struct StepHeader: View {
    let label: String
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.8))
                    .clipShape(Circle())
            }

            Spacer()

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryInk)
                .textCase(.uppercase)
                .tracking(0.8)

            Spacer()

            Color.clear.frame(width: 40, height: 40)
        }
    }
}

struct PerspectiveCard: View {
    let name: String
    let detail: String
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(name)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)

                        if let badge {
                            Text(badge)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(AppTheme.accentSoft)
                                .clipShape(Capsule())
                        }
                    }

                    Text(detail)
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
            }
            .padding(22)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.divider, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct FactorChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(selected ? AppTheme.accent : AppTheme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(selected ? AppTheme.accentSoft : .white)
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(selected ? AppTheme.accent.opacity(0.35) : AppTheme.divider, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
