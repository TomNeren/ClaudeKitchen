import KitchenCore
import SwiftUI

/// Every sentence the voice mode heard, newest first, with what it understood and answered.
struct VoiceLogView: View {
    @State private var entries: [VoiceLog.Entry] = []
    @State private var confirmsClear = false
    private let store: VoiceLogStore

    init(store: VoiceLogStore = .shared) {
        self.store = store
    }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "Noch nichts gehört", systemImage: "waveform",
                    description: Text("Im Kochmodus landet hier jeder erkannte Satz, auch die ignorierten."))
            }
            ForEach(entries.reversed()) { entry in
                VoiceLogRow(entry: entry)
            }
        }
        .navigationTitle("Sprachprotokoll")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: VoiceLog(entries: entries).exportText(), subject: Text("Sprachprotokoll ClaudeKitchen"))
                {
                    Label("Teilen", systemImage: "square.and.arrow.up")
                }
                .disabled(entries.isEmpty)
            }
            ToolbarItem(placement: .bottomBar) {
                Button("Protokoll löschen", systemImage: "trash", role: .destructive) {
                    confirmsClear = true
                }
                .disabled(entries.isEmpty)
            }
        }
        .confirmationDialog("Alle Einträge löschen?", isPresented: $confirmsClear, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                Task {
                    await store.clear()
                    await reload()
                }
            }
        }
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func reload() async {
        entries = await store.entries()
    }
}

private struct VoiceLogRow: View {
    let entry: VoiceLog.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("„\(entry.heard)“")
                    .font(.body)
                Spacer(minLength: 8)
                Text(entry.date, format: .dateTime.hour().minute().second())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Label(
                entry.command ?? "ignoriert",
                systemImage: entry.command == nil ? "ear.trianglebadge.exclamationmark" : "checkmark.circle"
            )
            .font(.subheadline)
            .foregroundStyle(entry.command == nil ? Color.secondary : Palette.herb)
            if let reply = entry.reply {
                Text(reply)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { VoiceLogView() }
}
