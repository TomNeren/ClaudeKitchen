import Foundation
import KitchenCore
import Observation

/// One "Mit Claude verbessern" run: feedback in, a checked variant out. Nothing is saved until the cook confirms.
@MainActor @Observable
final class ImproveRecipeModel {
    enum Phase {
        case ready
        case working
        case review(RecipeImprovement, changes: [VariantChange])
        case failed(String)
    }

    let original: Recipe
    let feedback: RecipeFeedback
    private(set) var phase: Phase = .ready

    private let variantID: RecipeID
    private let client: ClaudeClient
    private let profile: DeviceProfile
    private var request: Task<Void, Never>?

    init(
        original: Recipe, feedback: RecipeFeedback, takenIDs: Set<RecipeID>, client: ClaudeClient = ClaudeClient(),
        profile: DeviceProfile = .omniCook
    ) {
        self.original = original
        self.feedback = feedback
        self.variantID = ClaudeRecipeImprovement.variantID(for: original.id, taken: takenIDs)
        self.client = client
        self.profile = profile
    }

    var isWorking: Bool {
        if case .working = phase { return true }
        return false
    }

    func start() {
        guard !isWorking else { return }
        phase = .working
        request = Task { await run() }
    }

    /// Stops a running request, for example when the sheet closes, so no paid request keeps running.
    func cancel() {
        request?.cancel()
        request = nil
    }

    private func run() async {
        do {
            let improvement = try await client.improvement(
                of: original, feedback: feedback, variantID: variantID, profile: profile)
            try Task.checkCancellation()
            phase = .review(improvement, changes: improvement.changes(from: original))
        } catch is CancellationError {
            phase = .ready
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    static func message(for error: Error) -> String {
        guard let error = error as? ClaudeRecipeImprovement.ImprovementError else {
            return ImportRecipeModel.message(for: error)
        }
        switch error {
        case .wrongID, .wrongVariantOf, .markedVerified, .emptySummary, .duplicateIngredientID, .duplicateStepID,
            .draft:
            return "Claudes Antwort passte nicht ins Format. Bitte noch einmal versuchen."
        case .deviceIssues(let issues):
            return "Der Vorschlag hält die Grenzen des Geräts nicht ein (\(issues.count) Fehler). "
                + "Bitte noch einmal versuchen."
        case .unusedIngredients(let ids):
            return "Im Vorschlag kommen Zutaten in keinem Schritt vor: "
                + ids.map(\.rawValue).joined(separator: ", ") + ". Bitte noch einmal versuchen."
        case .catalogIssues:
            return "Der Vorschlag nennt Zutaten, die die App nicht kennt. Bitte noch einmal versuchen."
        }
    }
}
