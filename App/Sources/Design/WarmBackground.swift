import SwiftUI

/// Content-layer background: a slow, warm mesh gradient so the glass chrome above it has something to refract.
struct WarmBackground: View {
    var tint: Color = Palette.accent

    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.45], [0.6, 0.55], [1, 0.4],
                [0, 1], [0.4, 1], [1, 1],
            ],
            colors: [
                Palette.cream, tint.mix(with: Palette.cream, by: 0.7), Palette.cream,
                Palette.herb.mix(with: Palette.cream, by: 0.75), Palette.cream, tint.mix(with: Palette.cream, by: 0.6),
                Palette.cream, Palette.cool.mix(with: Palette.cream, by: 0.8), Palette.cream,
            ]
        )
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview {
    WarmBackground()
}
