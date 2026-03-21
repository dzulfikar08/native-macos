import SwiftUI
import CoreMedia
import AVFoundation

/// SwiftUI overlay view that appears when clips overlap, offering to add a transition
///
/// Features:
/// - Appears 60px above overlap zone
/// - Shows overlap duration
/// - Quick Dissolve button for instant apply
/// - Auto-dismisses after 10 seconds
/// - Respects 5-minute cooldown after dismissal
struct AutoTransitionPrompt: View {
    /// Overlap information to display
    let overlap: ClipOverlap

    /// Action when user taps "Quick Dissolve"
    let onApplyDissolve: () -> Void

    /// Action when user dismisses the prompt
    let onDismiss: () -> Void

    /// Environment value for dismiss
    @Environment(\.dismiss) private var dismiss

    /// Auto-dismiss timer
    @State private var timer: Timer?

    /// Time remaining before auto-dismiss
    @State private var timeRemaining: Double = 10.0

    var body: some View {
        VStack(spacing: 8) {
            // Header
            Text("Clips Overlapping")
                .font(.headline)
                .foregroundColor(.primary)

            // Overlap duration
            Text("Overlap: \(formatDuration(overlap.overlapDuration))")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Quick Dissolve button
            Button(action: {
                onApplyDissolve()
                dismiss()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Quick Dissolve")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)

            // Dismiss button
            Button("Dismiss") {
                onDismiss()
                dismiss()
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
        )
        .frame(maxWidth: 200)
        .onAppear {
            startAutoDismissTimer()
        }
        .onDisappear {
            stopAutoDismissTimer()
        }
    }

    // MARK: - Timer Management

    private func startAutoDismissTimer() {
        timeRemaining = 10.0

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
            timeRemaining -= 0.1

            if timeRemaining <= 0 {
                onDismiss()
                dismiss()
            }
        }
    }

    private func stopAutoDismissTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Formatting Helpers

    private func formatDuration(_ duration: CMTime) -> String {
        let seconds = CMTimeGetSeconds(duration)
        if seconds < 1.0 {
            return String(format: "%.1fs", seconds)
        } else {
            return String(format: "%.2gs", seconds)
        }
    }
}

// MARK: - Preview

#Preview {
    AutoTransitionPrompt(
        overlap: ClipOverlap(
            leadingClip: VideoClip.mock,
            trailingClip: VideoClip.mock,
            overlapDuration: CMTime(seconds: 1.5, preferredTimescale: 600),
            overlapRange: CMTime(seconds: 5.0, preferredTimescale: 600)...CMTime(seconds: 6.5, preferredTimescale: 600)
        ),
        onApplyDissolve: {},
        onDismiss: {}
    )
}

// MARK: - Mock Data for Preview

#if DEBUG
extension VideoClip {
    static let mock = VideoClip(
        name: "Mock Clip",
        asset: AVAsset(url: URL(fileURLWithPath: "/dev/null")),
        timeRangeInSource: CMTimeRange(
            start: CMTime(seconds: 0, preferredTimescale: 600),
            duration: CMTime(seconds: 10, preferredTimescale: 600)
        ),
        timeRangeInTimeline: CMTimeRange(
            start: CMTime(seconds: 0, preferredTimescale: 600),
            duration: CMTime(seconds: 10, preferredTimescale: 600)
        ),
        trackID: UUID()
    )
}
#endif
