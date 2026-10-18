import SwiftUI

private struct HapticModifier<Trigger: Equatable>: ViewModifier {
    @Environment(AppSettings.self) private var settings
    let feedback: SensoryFeedback
    let trigger: Trigger

    func body(content: Content) -> some View {
        content.sensoryFeedback(trigger: trigger) { _, _ in
            settings.values.hapticsEnabled ? feedback : nil
        }
    }
}

extension View {
    func haptic<Trigger: Equatable>(_ feedback: SensoryFeedback, trigger: Trigger) -> some View {
        modifier(HapticModifier(feedback: feedback, trigger: trigger))
    }
}
