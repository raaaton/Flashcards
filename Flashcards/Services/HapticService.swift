import UIKit

enum HapticEvent {
    case selection
    case flip
    case correct
    case review
    case wrong
    case completion
}

@MainActor
enum HapticService {
    static func play(_ event: HapticEvent) {
        guard AppPreferences.hapticsEnabled else { return }

        switch event {
        case .selection:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred(intensity: 0.62)
        case .flip:
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred(intensity: 0.42)
        case .correct:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred(intensity: 0.72)
        case .review:
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred(intensity: 0.72)
        case .wrong:
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred(intensity: 0.46)
        case .completion:
            playCompletionSequence()
        }
    }

    private static func playCompletionSequence() {
        let notification = UINotificationFeedbackGenerator()
        let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
        let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)

        notification.prepare()
        rigidImpact.prepare()
        heavyImpact.prepare()
        notification.notificationOccurred(.success)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            guard AppPreferences.hapticsEnabled else { return }
            rigidImpact.impactOccurred(intensity: 1)

            try? await Task.sleep(for: .milliseconds(105))
            guard AppPreferences.hapticsEnabled else { return }
            heavyImpact.impactOccurred(intensity: 1)
        }
    }
}
