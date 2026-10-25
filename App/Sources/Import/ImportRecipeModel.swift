import Foundation
import KitchenCore
import Observation

/// One import: text or link in, a checked recipe out. Nothing is saved until the cook confirms.
@MainActor @Observable
final class ImportRecipeModel {
    enum Phase {
        case editing
        case working(String)
        case preview(Recipe, issues: [ValidationIssue])
        case failed(String)
    }

    var text = ""
    var link = ""
    private(set) var phase: Phase = .editing

    private let client: ClaudeClient
    private let store: any RecipeStore
    private let profile: DeviceProfile

    init(
        client: ClaudeClient = ClaudeClient(), store: any RecipeStore = FileRecipeStore.shared,
        profile: DeviceProfile = .omniCook
    ) {
        self.client = client
        self.store = store
        self.profile = profile
    }

    var hasKey: Bool { APIKeyStore.hasKey }

    var canConvert: Bool {
        if case .working = phase { return false }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || linkURL != nil
    }

    /// The preview can be saved only without errors; warnings are shown but allowed.
    var canSave: Bool {
        guard case .preview(_, let issues) = phase else { return false }
        return !issues.contains { $0.severity == .error }
    }

    private var linkURL: URL? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme == "https" || url.scheme == "http" else { return nil }
        return url
    }

    func convert() async {
        do {
            var source = text
            if source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let url = linkURL {
                phase = .working("Seite wird geladen")
                source = try await client.pageText(at: url)
            }
            phase = .working("Claude bereitet das Rezept auf")
            let draft = try await client.draft(for: source, profile: profile)
            let recipe = try draft.recipe(id: RecipeID("eigen-\(UUID().uuidString.prefix(8).lowercased())"))
            phase = .preview(recipe, issues: profile.validate(recipe))
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    func save() async -> Bool {
        guard canSave, case .preview(let recipe, _) = phase else { return false }
        do {
            try await store.save(recipe)
            return true
        } catch {
            phase = .failed("Speichern fehlgeschlagen: \(error.localizedDescription)")
            return false
        }
    }

    func edit() {
        phase = .editing
    }

    private static func message(for error: Error) -> String {
        switch error {
        case ClaudeClient.ClientError.missingKey:
            return "Kein API-Schlüssel hinterlegt. Trag ihn in den Einstellungen ein."
        case ClaudeClient.ClientError.network(let detail):
            return "Keine Verbindung: \(detail)"
        case ClaudeRecipeImport.ResponseError.api(let type, let detail):
            switch type {
            case "authentication_error": return "Der API-Schlüssel wurde abgelehnt."
            case "permission_error", "billing_error": return "Das Anthropic-Konto erlaubt die Anfrage nicht: \(detail)"
            case "rate_limit_error", "overloaded_error":
                return "Claude ist gerade ausgelastet. Bitte gleich noch einmal."
            default: return "Claude meldet einen Fehler: \(detail)"
            }
        case ClaudeRecipeImport.ResponseError.refusal:
            return "Claude hat die Anfrage abgelehnt."
        case ClaudeRecipeImport.ResponseError.truncated:
            return "Das Rezept war zu lang für eine Antwort. Kürze den Text und versuch es noch einmal."
        case ClaudeRecipeImport.ResponseError.missingRecipe, is DecodingError:
            return "Die Antwort enthielt kein lesbares Rezept. Bitte noch einmal versuchen."
        case let draftError as RecipeDraftError:
            return "Das Rezept passt nicht ins Format (\(draftError)). Bitte noch einmal versuchen."
        default:
            return error.localizedDescription
        }
    }
}
