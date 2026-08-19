import SwiftUI

struct StudyCardFace: View, Animatable {
    let front: String
    let back: String
    let obscuresContent: Bool
    var angle: Double

    init(
        front: String,
        back: String,
        obscuresContent: Bool = false,
        angle: Double
    ) {
        self.front = front
        self.back = back
        self.obscuresContent = obscuresContent
        self.angle = angle
    }

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            cardFace(front)
                .opacity(normalizedAngle < 90 ? 1 : 0)

            cardFace(back)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(normalizedAngle >= 90 ? 1 : 0)
        }
        .rotation3DEffect(
            .degrees(angle),
            axis: (x: 0, y: 1, z: 0),
            perspective: StudyAnimationMetrics.flipPerspective
        )
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
    }

    private var normalizedAngle: Double {
        angle.truncatingRemainder(dividingBy: 360)
    }

    private func cardFace(_ value: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.cardBackground)

            Text(value)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)
                .padding(30)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(obscuresContent ? 0 : 1)
        }
    }
}
