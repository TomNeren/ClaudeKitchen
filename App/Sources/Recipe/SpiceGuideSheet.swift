import KitchenCore
import SwiftUI

/// What a spice or seasoning is: origin, components of a blend, taste, handling and a substitute. Plain content on
/// solid cards, no glass.
struct SpiceGuideSheet: View {
    let name: String
    let entry: SpiceGuide.Entry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(SpiceGuideText.kind(entry.kind).uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(Palette.accent)
                    Text(entry.summary)
                        .font(.body)
                        .foregroundStyle(Palette.ink)
                    if !entry.components.isEmpty {
                        card(title: "Drin steckt", systemImage: "square.grid.3x3") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(entry.components, id: \.self) { component in
                                    Label(component, systemImage: "circle.fill")
                                        .labelStyle(BulletLabelStyle())
                                }
                            }
                        }
                    }
                    card(title: "Geschmack", systemImage: "mouth") { Text(entry.taste) }
                    if let tip = entry.tip {
                        card(title: "Im Topf", systemImage: "frying.pan") { Text(tip) }
                    }
                    if let substitute = entry.substitute {
                        card(title: "Nicht im Haus?", systemImage: "arrow.triangle.2.circlepath") { Text(substitute) }
                    }
                }
                .padding(20)
            }
            .background(Palette.cream)
            .navigationTitle(name)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func card(title: String, systemImage: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(Palette.ink)
            content()
                .font(.body)
                .foregroundStyle(Palette.ink)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

/// A small dot instead of the icon's full size, for list items.
private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon
                .font(.system(size: 6))
                .foregroundStyle(Palette.muted)
            configuration.title
        }
    }
}

/// The ingredient a guide sheet is open for.
struct SpiceGuideRequest: Identifiable {
    let name: String
    let entry: SpiceGuide.Entry
    var id: FoodID { entry.food }
}

enum SpiceGuideText {
    static func kind(_ kind: SpiceGuide.Entry.Kind) -> String {
        switch kind {
        case .blend: "Gewürzmischung"
        case .spice: "Gewürz"
        case .herb: "Kraut und Blatt"
        case .paste: "Würzpaste"
        case .liquid: "Würzflüssigkeit"
        case .other: "Zutat"
        }
    }

    /// Spoken by the voice mode: "Garam Masala: Nordindische Mischung … Drin sind … Geschmack: … Ersatz: …"
    static func spoken(name: String, entry: SpiceGuide.Entry) -> String {
        var parts = ["\(name): \(entry.summary)"]
        if !entry.components.isEmpty {
            parts.append("Drin sind \(entry.components.joined(separator: ", ")).")
        }
        parts.append("Geschmack: \(entry.taste)")
        if let substitute = entry.substitute {
            parts.append("Ersatz: \(substitute)")
        }
        return parts.joined(separator: " ")
    }
}

#Preview {
    if let entry = SpiceGuide.shared?.entries.first {
        Text("Rezept")
            .sheet(isPresented: .constant(true)) {
                SpiceGuideSheet(name: "Garam Masala", entry: entry)
            }
    }
}
