import Foundation
import KitchenCore
import Observation
import PDFKit

/// One import: text, link or PDF pages in, a checked recipe out. Nothing is saved until the cook confirms.
@MainActor @Observable
final class ImportRecipeModel {
    enum Phase {
        case editing
        case working(String)
        case preview(Recipe, issues: [ValidationIssue])
        /// Stored from the editor; the preview is gone, so Claude's version cannot be saved over the edits.
        case saved
        case failed(String)
    }

    var text = "" {
        didSet { if text != pdfText { textOrigin = nil } }
    }
    var link = ""
    /// The PDF chosen as a source, with the pages to read. Its text lands in `text`, so the cook sees and can
    /// correct it before anything is sent.
    private(set) var pdf: PDFSource?
    /// Where the current `text` came from, while it is still unchanged.
    private(set) var textOrigin: ScannedText.Source?
    /// The text as last read from the PDF, to notice when the cook edits it.
    private var pdfText: String?
    private(set) var phase: Phase = .editing
    /// Read once per screen; the Keychain is not queried on every render.
    private(set) var hasKey: Bool

    private let client: ClaudeClient
    private let reader = PDFRecipeReader()
    private let store: any RecipeStore
    let profile: DeviceProfile
    private let catalog: FoodCatalog?
    private var conversion: Task<Void, Never>?

    init(
        client: ClaudeClient = ClaudeClient(), store: any RecipeStore = FileRecipeStore.shared,
        profile: DeviceProfile = .omniCook, catalog: FoodCatalog? = FoodCatalog.shared,
        hasKey: Bool = APIKeyStore.hasKey
    ) {
        self.client = client
        self.store = store
        self.profile = profile
        self.catalog = catalog
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

    /// Opens a PDF picked in the file importer. The file is read at once, since its access ends with this call.
    func openPDF(at url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let document = PDFDocument(data: data), !document.isLocked,
            document.pageCount > 0
        else {
            phase = .failed(Self.message(for: PDFRecipeReader.ReaderError.unreadable))
            return
        }
        pdf = PDFSource(name: url.deletingPathExtension().lastPathComponent, data: data, document: document)
    }

    func closePDF() {
        pdf = nil
    }

    func togglePage(_ index: Int) {
        pdf?.selection.toggle(index)
    }

    var canReadPDF: Bool {
        if case .working = phase { return false }
        return pdf.map { !$0.selection.pages.isEmpty } ?? false
    }

    /// Reads the chosen pages into `text`, replacing what was there. Needs no API key; nothing leaves the device.
    func readPDF() {
        guard canReadPDF, let pdf else { return }
        conversion = Task { await runReading(pdf) }
    }

    private func runReading(_ pdf: PDFSource) async {
        phase = .working("Seiten werden gelesen")
        do {
            let result = try await reader.read(pdf.data, pages: pdf.selection.pages)
            try Task.checkCancellation()
            pdfText = result.text
            text = result.text
            textOrigin = result.source
            phase = .editing
        } catch is CancellationError {
            phase = .editing
        } catch {
            phase = .failed(Self.message(for: error))
        }
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

    /// The converted recipe while the preview is shown, for example to open it in the editor.
    var previewRecipe: Recipe? {
        if case .preview(let recipe, _) = phase { recipe } else { nil }
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

    /// Saves the recipe as changed in the editor, which checked it against the same profile. Returns false when
    /// writing failed; the editor then stays open with the changes.
    func saveEdited(_ recipe: Recipe) async -> Bool {
        do {
            try await store.save(recipe)
            phase = .saved
            return true
        } catch {
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
            let converted = try await client.recipe(for: source, id: id, profile: profile)
            try Task.checkCancellation()
            // Foods as the editor assigns them, so preview, editor and the saved recipe agree on every check.
            let recipe = catalog.map { converted.assigningFoods(from: $0) } ?? converted
            phase = .preview(recipe, issues: profile.validate(recipe))
        } catch is CancellationError {
            phase = .editing
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    static func message(for error: Error) -> String {
        switch error {
        case PDFRecipeReader.ReaderError.unreadable:
            return "Die PDF-Datei lässt sich nicht öffnen. Ist sie beschädigt oder mit einem Passwort geschützt?"
        case PDFRecipeReader.ReaderError.noText:
            return "Auf den gewählten Seiten war kein Text zu finden. Wähl die Seiten mit dem Rezept."
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

/// A PDF chosen for an import. `PDFDocument` is not `Sendable`, so it stays on the main actor for page previews;
/// the reader gets the raw data.
struct PDFSource {
    let name: String
    let data: Data
    let document: PDFDocument
    var selection: PageSelection

    init(name: String, data: Data, document: PDFDocument) {
        self.name = name
        self.data = data
        self.document = document
        selection = PageSelection(pageCount: document.pageCount)
    }

    /// The printed page number when the PDF carries one, otherwise the position counted from 1.
    func label(of index: Int) -> String {
        document.page(at: index)?.label ?? "\(index + 1)"
    }
}
