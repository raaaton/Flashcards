import SwiftUI

struct StudyCardFace: View, Animatable {
    let front: String
    let back: String
    var angle: Double

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            cardText(front)
                .opacity(normalizedAngle < 90 ? 1 : 0)

            cardText(back)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(normalizedAngle >= 90 ? 1 : 0)
        }
        .rotation3DEffect(
            .degrees(angle),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.68
        )
    }

    private var normalizedAngle: Double {
        angle.truncatingRemainder(dividingBy: 360)
    }

    private func cardText(_ value: String) -> some View {
        Text(value)
            .font(.title2.weight(.semibold))
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.72)
            .padding(30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
