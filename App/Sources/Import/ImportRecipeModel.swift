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
    /// Read once per screen; the Keychain is not queried on every render.
    private(set) var hasKey: Bool

    private let client: ClaudeClient
    private let store: any RecipeStore
    private let profile: DeviceProfile
    private var conversion: Task<Void, Never>?

    init(
        client: ClaudeClient = ClaudeClient(), store: any RecipeStore = FileRecipeStore.shared,
        profile: DeviceProfile = .omniCook, hasKey: Bool = APIKeyStore.hasKey
    ) {
        self.client = client
        self.store = store
        self.profile = profile
        self.hasKey = hasKey
    }

    var canConvert: Bool {
        if case .working = phase { return false }
        return hasKey && (!trimmedText.isEmpty || linkURL != nil)
    }

    /// The preview can be saved only without errors; warnings are shown but allowed.
    var canSave: Bool {
        guard case .preview(_, let issues) = phase else { return false }
        return !issues.contains { $0.severity == .error }
    }

    /// A link that will be loaded, or nil. Only HTTPS, since the app allows no plain-HTTP loads.
    var linkURL: URL? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme == "https", url.host() != nil else { return nil }
        return url
    }

    var linkIsInsecure: Bool {
        link.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("http://")
    }

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    func refreshKey() {
        hasKey = APIKeyStore.hasKey
    }

    /// Starts the conversion. Text wins over the link when both are given.
    func convert() {
        guard canConvert else { return }
        conversion = Task { await runConversion() }
    }

    /// Stops a running conversion, for example when the sheet closes, so no paid request keeps running.
    func cancel() {
        conversion?.cancel()
        conversion = nil
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

    /// Back to the text and link, which are kept, to adjust and convert again.
    func edit() {
        phase = .editing
    }

    private func runConversion() async {
        do {
            var source = trimmedText
            if source.isEmpty, let url = linkURL {
                phase = .working("Seite wird geladen")
                source = try await client.pageText(at: url)
            }
            phase = .working("Claude bereitet das Rezept auf")
            let id = RecipeID("eigen-\(UUID().uuidString.prefix(8).lowercased())")
            let recipe = try await client.recipe(for: source, id: id, profile: profile)
            try Task.checkCancellation()
            phase = .preview(recipe, issues: profile.validate(recipe))
        } catch is CancellationError {
            phase = .editing
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: Error) -> String {
        switch error {
        case ClaudeClient.ClientError.missingKey:
            return "Kein API-Schlüssel hinterlegt. Trag ihn in den Einstellungen ein."
        case ClaudeClient.ClientError.network(let detail):
            return "Keine Verbindung: \(detail)"
        case ClaudeClient.ClientError.page(let status):
            return "Die Seite ließ sich nicht laden (Status \(status)). Kopiere den Rezepttext stattdessen."
        case ClaudeClient.ClientError.insecureLink:
            return "Nur https-Links lassen sich laden. Kopiere den Rezepttext stattdessen."
        case ClaudeRecipeImport.ResponseError.api(let type, let detail):
            switch type {
            case "authentication_error": return "Der API-Schlüssel wurde abgelehnt."
            case "permission_error", "billing_error": return "Das Anthropic-Konto erlaubt die Anfrage nicht: \(detail)"
            case "rate_limit_error", "overloaded_error":
                return "Claude ist gerade ausgelastet. Bitte gleich noch einmal."
            default: return "Claude meldet einen Fehler: \(detail)"
            }
        case ClaudeRecipeImport.ResponseError.http(let status):
            return "Der Dienst antwortet gerade nicht (Status \(status)). Bitte gleich noch einmal."
        case ClaudeRecipeImport.ResponseError.refusal:
            return "Claude hat die Anfrage abgelehnt."
        case ClaudeRecipeImport.ResponseError.truncated:
            return "Das Rezept war zu lang für eine Antwort. Kürze den Text und versuch es noch einmal."
        case ClaudeRecipeImport.ResponseError.missingRecipe:
            return "Die Antwort enthielt kein lesbares Rezept. Bitte noch einmal versuchen."
        case let draftError as RecipeDraftError:
            return "Das Rezept passt nicht ins Format (\(draftError)). Bitte noch einmal versuchen."
        default:
            return error.localizedDescription
        }
    }
}
