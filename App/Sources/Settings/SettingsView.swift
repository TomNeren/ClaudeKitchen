import KitchenCore
import SwiftUI

/// The Anthropic API key for the recipe import (stored only in this device's Keychain) and the voice log.
struct SettingsView: View {
    @State private var key = ""
    @State private var hasKey = APIKeyStore.hasKey
    @AppStorage(VoiceLogStore.enabledKey) private var logsVoice = true
    @AppStorage(HealthGoals.vegetarianByDefaultKey) private var vegetarianByDefault = true
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
                    Toggle("Vegetarisch als Standard", isOn: $vegetarianByDefault)
                } header: {
                    Text("Rezepte")
                } footer: {
                    Text(
                        "Rezepte mit Fleisch öffnen mit Tofu statt Fleisch; das Original wählst du oben im Ziel-Menü. Fisch und Würzen wie Fischsauce bleiben, ihre vegetarische Alternative steht in der Ersatzliste."
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

                BuildInfoSection(info: BuildInfo(infoDictionary: Bundle.main.infoDictionary ?? [:]))
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

/// Version, build and git commit of the installed app, so a device build can be matched to the repo.
private struct BuildInfoSection: View {
    let info: BuildInfo

    var body: some View {
        Section {
            LabeledContent("Version", value: info.version ?? "unbekannt")
            LabeledContent("Build", value: info.build ?? "unbekannt")
            LabeledContent("Stand") {
                Text(commitText)
                    .monospaced()
                    .textSelection(.enabled)
            }
            if let date = info.commitDate {
                LabeledContent("Vom", value: date.formatted(.dateTime.day().month(.wide).year().timeZone(.gmt)))
            }
        } header: {
            Text("Über die App")
        } footer: {
            if info.hasLocalChanges {
                Text("Gebaut mit Änderungen, die noch nicht im Repo sind.")
            }
        }
    }

    private var commitText: String {
        guard let commit = info.commit else { return "unbekannt" }
        return info.hasLocalChanges ? "\(commit)+" : commit
    }
}

#Preview {
    SettingsView()
}
