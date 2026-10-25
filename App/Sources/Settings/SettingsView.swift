import SwiftUI

/// The Anthropic API key for the recipe import. Stored only in this device's Keychain.
struct SettingsView: View {
    @State private var key = ""
    @State private var hasKey = APIKeyStore.hasKey
    @Environment(\.dismiss) private var dismiss

    init() {}

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if hasKey {
                        Label("Schlüssel ist hinterlegt", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Palette.herb)
                        Button("Schlüssel entfernen", role: .destructive) {
                            APIKeyStore.delete()
                            hasKey = false
                        }
                    } else {
                        SecureField("sk-ant-…", text: $key)
                            .textContentType(.password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Speichern") {
                            hasKey = APIKeyStore.save(key.trimmingCharacters(in: .whitespacesAndNewlines))
                            key = ""
                        }
                        .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("Anthropic API-Schlüssel")
                } footer: {
                    Text(
                        "Für den Rezept-Import. Einen Schlüssel erstellst du unter console.anthropic.com. Er bleibt nur auf diesem Gerät; jeder Import kostet ein paar Cent auf deinem Anthropic-Konto."
                    )
                }
            }
            .navigationTitle("Einstellungen")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
