import SwiftUI

/// Asked once after "Fertig": stars and an optional note. Skipping keeps the log entry without a rating.
struct CookRatingSheet: View {
    let recipeName: String
    let onSave: (_ rating: Int?, _ note: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var stars = 0
    @State private var note = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(recipeName)
                    .font(.title3.weight(.semibold))
                    .fontDesign(.serif)
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            stars = stars == value ? 0 : value
                        } label: {
                            Image(systemName: value <= stars ? "star.fill" : "star")
                                .font(.largeTitle)
                                .foregroundStyle(value <= stars ? Color.yellow : Color.secondary)
                                .frame(minWidth: 52, minHeight: 52)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(value) von 5 Sternen")
                        .accessibilityAddTraits(value == stars ? .isSelected : [])
                    }
                }
                .sensoryFeedback(.selection, trigger: stars)
                TextField("Was würdest du beim nächsten Mal ändern?", text: $note, axis: .vertical)
                    .lineLimit(2...5)
                    .padding(12)
                    .background(Palette.surface, in: .rect(cornerRadius: 14))
                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Wie war's?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Überspringen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        onSave(stars == 0 ? nil : stars, note)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    CookRatingSheet(recipeName: "Dal") { _, _ in }
}
