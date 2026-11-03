import SwiftUI

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    var tint: Color?
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(glass, in: .rect(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private var glass: Glass {
        if let tint {
            return Glass.regular.tint(tint)
        }
        return Glass.regular
    }
}
