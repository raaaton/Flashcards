import SwiftUI

private struct ConfettiPiece: Identifiable, Sendable {
    let id: Int
    let horizontalPosition: CGFloat
    let horizontalDrift: CGFloat
    let delay: Double
    let duration: Double
    let rotation: Double
    let width: CGFloat
    let height: CGFloat
    let usesAccent: Bool
}

struct ConfettiView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFalling = false
    @State private var isVisible = true

    private static let pieces: [ConfettiPiece] = (0..<34).map { index in
        let seed = (index * 73 + 19) % 101
        return ConfettiPiece(
            id: index,
            horizontalPosition: CGFloat((seed * 37) % 100) / 100,
            horizontalDrift: CGFloat(((seed * 17) % 41) - 20),
            delay: Double((index * 11) % 24) / 100,
            duration: 0.82 + Double((index * 7) % 38) / 100,
            rotation: Double(180 + (index * 47) % 360),
            width: CGFloat(5 + (index % 3) * 2),
            height: CGFloat(10 + (index % 4) * 2),
            usesAccent: index.isMultiple(of: 3) == false
        )
    }

    var body: some View {
        GeometryReader { proxy in
            if isVisible && !reduceMotion {
                ZStack {
                    ForEach(Self.pieces) { piece in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(piece.usesAccent ? Theme.accent : .white)
                            .frame(width: piece.width, height: piece.height)
                            .opacity(piece.usesAccent ? 0.92 : 0.78)
                            .rotationEffect(.degrees(isFalling ? piece.rotation : 0))
                            .position(
                                x: proxy.size.width * piece.horizontalPosition
                                    + (isFalling ? piece.horizontalDrift : 0),
                                y: isFalling ? proxy.size.height + 28 : -24
                            )
                            .animation(
                                .easeIn(duration: piece.duration).delay(piece.delay),
                                value: isFalling
                            )
                    }
                }
                .onAppear {
                    isFalling = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(1_650))
                        isVisible = false
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
