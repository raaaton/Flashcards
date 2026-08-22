import CoreHaptics
import UIKit

enum HapticEvent {
    case selection
    case reorder
    case flip
    case correct
    case review
    case wrong
    case completion
}

@MainActor
enum HapticService {
    private static var completionEngine: CHHapticEngine?
    private static let selectionGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let reorderGenerator = UIImpactFeedbackGenerator(style: .rigid)

    static func play(_ event: HapticEvent) {
        guard AppPreferences.hapticsEnabled else { return }

        switch event {
        case .selection:
            selectionGenerator.prepare()
            selectionGenerator.impactOccurred(intensity: 1)
            selectionGenerator.prepare()
        case .reorder:
            reorderGenerator.prepare()
            reorderGenerator.impactOccurred(intensity: 0.82)
            reorderGenerator.prepare()
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
        guard completionEngine == nil else { return }

        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            do {
                let engine = try CHHapticEngine()
                let maximumIntensity = CHHapticEventParameter(
                    parameterID: .hapticIntensity,
                    value: 1
                )
                let sharpImpact = CHHapticEventParameter(
                    parameterID: .hapticSharpness,
                    value: 0.9
                )
                let broadImpact = CHHapticEventParameter(
                    parameterID: .hapticSharpness,
                    value: 0.45
                )
                let events = [
                    CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [maximumIntensity, broadImpact],
                        relativeTime: 0,
                        duration: 0.065
                    ),
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [maximumIntensity, sharpImpact],
                        relativeTime: 0
                    ),
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [maximumIntensity, sharpImpact],
                        relativeTime: 0.085
                    ),
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [maximumIntensity, broadImpact],
                        relativeTime: 0.18
                    )
                ]
                let pattern = try CHHapticPattern(events: events, parameters: [])
                let player = try engine.makePlayer(with: pattern)

                completionEngine = engine
                try engine.start()
                try player.start(atTime: CHHapticTimeImmediate)

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(320))
                    engine.stop(completionHandler: nil)
                    if completionEngine === engine {
                        completionEngine = nil
                    }
                }
                return
            } catch {
                completionEngine = nil
            }
        }

        playCompletionFallback()
    }

    private static func playCompletionFallback() {
        let firstImpact = UIImpactFeedbackGenerator(style: .heavy)
        let secondImpact = UIImpactFeedbackGenerator(style: .rigid)
        let finalImpact = UIImpactFeedbackGenerator(style: .heavy)

        firstImpact.prepare()
        secondImpact.prepare()
        finalImpact.prepare()
        firstImpact.impactOccurred(intensity: 1)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(75))
            guard AppPreferences.hapticsEnabled else { return }
            secondImpact.impactOccurred(intensity: 1)

            try? await Task.sleep(for: .milliseconds(85))
            guard AppPreferences.hapticsEnabled else { return }
            finalImpact.impactOccurred(intensity: 1)
        }
    }
}
