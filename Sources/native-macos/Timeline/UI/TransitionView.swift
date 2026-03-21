import SwiftUI

struct TransitionView: View {
    /// The transition to display
    let transition: TransitionClip

    /// Whether this transition is selected
    let isSelected: Bool

    /// Whether drag handles are visible
    let showHandles: Bool

    /// Leading drag handle frame
    let leadingHandleFrame: CGRect

    /// Trailing drag handle frame
    let trailingHandleFrame: CGRect

    /// Action when transition is tapped
    let onTap: () -> Void

    /// Action when leading handle is dragged
    let onLeadingHandleDrag: (CGFloat) -> Void

    /// Action when trailing handle is dragged
    let onTrailingHandleDrag: (CGFloat) -> Void

    var body: some View {
        ZStack {
            // Transition background
            RoundedRectangle(cornerRadius: 4)
                .fill(transitionColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(selectionBorder, lineWidth: isSelected ? 2 : 0)
                )

            // Transition icon
            transitionIcon
                .padding(4)

            // Drag handles
            if showHandles {
                leadingHandle
                trailingHandle
            }
        }
        .frame(height: 30)
        .onTapGesture {
            onTap()
        }
    }

    private var transitionColor: Color {
        switch transition.type {
        case .crossfade:
            return .blue.opacity(0.6)
        case .fadeToColor:
            return .purple.opacity(0.6)
        case .wipe:
            return .green.opacity(0.6)
        case .iris:
            return .orange.opacity(0.6)
        case .blinds:
            return .yellow.opacity(0.6)
        case .custom:
            return .pink.opacity(0.6)
        }
    }

    private var selectionBorder: Color {
        return .cyan
    }

    @ViewBuilder
    private var transitionIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
    }

    private var iconName: String {
        switch transition.type {
        case .crossfade:
            return "circle.fill"
        case .fadeToColor:
            return "circle.lefthalf.filled"
        case .wipe:
            return "arrow.right.circle.fill"
        case .iris:
            return "circle.circle"
        case .blinds:
            return "line.3.horizontal"
        case .custom:
            return "star.fill"
        }
    }

    private var leadingHandle: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(.white)
            .frame(width: 4, height: 12)
            .position(x: leadingHandleFrame.midX, y: leadingHandleFrame.midY)
    }

    private var trailingHandle: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(.white)
            .frame(width: 4, height: 12)
            .position(x: trailingHandleFrame.midX, y: trailingHandleFrame.midY)
    }
}
