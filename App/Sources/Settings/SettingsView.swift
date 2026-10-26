import SwiftUI

/// The Anthropic API key for the recipe import (stored only in this device's Keychain) and the voice log.
struct SettingsView: View {
    @State private var key = ""
    @State private var hasKey = APIKeyStore.hasKey
    @AppStorage(VoiceLogStore.enabledKey) private var logsVoice = true
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

                Section {
                    Toggle("Erkannte Sätze protokollieren", isOn: $logsVoice)
                    NavigationLink("Sprachprotokoll ansehen") { VoiceLogView() }
                } header: {
                    Text("Sprachmodus")
                } footer: {
                    Text(
                        "Hilft beim Nachschärfen der Befehle: Jeder Satz, den der Kochmodus hört, steht hier mit dem, was die App verstanden hat. Das Protokoll bleibt auf diesem Gerät, bis du es teilst oder löschst."
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

#Preview {
    SettingsView()
}
