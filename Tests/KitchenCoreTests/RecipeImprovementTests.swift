import Foundation
import Testing

@testable import KitchenCore

@Suite("Recipe improvement")
struct RecipeImprovementTests {
    private let profile = DeviceProfile.omniCook

    private func original() throws -> Recipe {
        let recipes = try RecipeLibrary.bundled()
        return try #require(recipes.first { $0.steps.contains { $0.setting?.heat != nil } })
    }

    /// The recipe as the model would echo it, as a JSON object, so tests can change single values.
    private func answer(echoing recipe: Recipe, id: RecipeID) -> [String: Any] {
        let index = Dictionary(uniqueKeysWithValues: recipe.ingredients.enumerated().map { ($1.id, $0) })
        let ingredients: [[String: Any]] = recipe.ingredients.map { ingredient in
            var quantity: Any = NSNull()
            var unit: Any = NSNull()
            if case .measured(let value, let measure) = ingredient.amount {
                quantity = value
                unit = measure.rawValue
            }
            return [
                "id": ingredient.id.rawValue, "name": ingredient.name, "quantity": quantity, "unit": unit,
                "note": ingredient.note ?? NSNull(), "scales": ingredient.scales,
            ]
        }
        let steps: [[String: Any]] = recipe.steps.map { step in
            var setting: Any = NSNull()
            if let value = step.setting {
                var celsius: Any = NSNull()
                if case .celsius(let degrees) = value.heat { celsius = degrees }
                var speed: Any = NSNull()
                var reverse = false
                switch value.rotation {
                case .forward(let forward): speed = forward
                case .reverse(let backward):
                    speed = backward
                    reverse = true
                case nil: break
                }
                setting = [
                    "program": value.program.rawValue, "celsius": celsius, "steam": value.heat == .steam,
                    "speed": speed, "reverse": reverse,
                    "seconds": value.duration.map { Int($0.components.seconds) } ?? NSNull(),
                ]
            }
            return [
                "id": step.id.rawValue, "phase": step.phase, "text": step.text, "note": step.note ?? NSNull(),
                "ingredientIndexes": step.ingredientIDs.compactMap { index[$0] }, "setting": setting,
                "accessory": step.accessory?.rawValue ?? NSNull(), "freshPot": step.freshPot,
            ]
        }
        return [
            "summary": "Weniger Salz, wie gewünscht.", "id": id.rawValue, "variantOf": recipe.id.rawValue,
            "verified": false, "name": recipe.name, "tag": recipe.tag, "baseServings": recipe.baseServings,
            "totalMinutes": recipe.totalMinutes, "ingredients": ingredients, "steps": steps,
        ]
    }

    private func response(_ answer: [String: Any]) throws -> Data {
        let text = String(decoding: try JSONSerialization.data(withJSONObject: answer), as: UTF8.self)
        return try JSONSerialization.data(withJSONObject: [
            "content": [["type": "text", "text": text]], "stop_reason": "end_turn",
        ])
    }

    @Test func acceptsAValidImprovementAndKeepsIds() throws {
        let original = try original()
        let id = ClaudeRecipeImprovement.variantID(for: original.id, taken: [])
        var json = answer(echoing: original, id: id)
        var steps = try #require(json["steps"] as? [[String: Any]])
        steps[0]["text"] = "Neu formuliert."
        json["steps"] = steps

        let result = try ClaudeRecipeImprovement.improvement(
            fromResponse: try response(json), original: original, variantID: id, profile: profile)
        #expect(result.recipe.id == RecipeID("\(original.id.rawValue)-v1"))
        #expect(result.recipe.variantOf == original.id)
        #expect(!result.recipe.verified)
        #expect(result.recipe.ingredients.map(\.id) == original.ingredients.map(\.id))
        #expect(result.recipe.ingredients.map(\.food) == original.ingredients.map(\.food))
        #expect(result.recipe.steps.map(\.id) == original.steps.map(\.id))
        #expect(result.recipe.steps[0].text == "Neu formuliert.")
        #expect(result.summary == "Weniger Salz, wie gewünscht.")
    }

    @Test func rejectsAnInvalidDeviceValue() throws {
        let original = try original()
        let id = RecipeID("\(original.id.rawValue)-v1")
        var json = answer(echoing: original, id: id)
        var steps = try #require(json["steps"] as? [[String: Any]])
        let index = try #require(original.steps.firstIndex { $0.setting?.heat != nil && $0.setting?.heat != .steam })
        var setting = try #require(steps[index]["setting"] as? [String: Any])
        setting["celsius"] = 300
        steps[index]["setting"] = setting
        json["steps"] = steps

        #expect {
            try ClaudeRecipeImprovement.improvement(
                fromResponse: try response(json), original: original, variantID: id, profile: profile)
        } throws: { error in
            guard case ClaudeRecipeImprovement.ImprovementError.deviceIssues(let issues) = error else { return false }
            return issues.contains { $0.kind == .temperatureOutOfRange(300) }
        }
    }

    @Test func rejectsAMissingVariantOf() throws {
        let original = try original()
        let id = RecipeID("\(original.id.rawValue)-v1")
        var json = answer(echoing: original, id: id)
        json["variantOf"] = nil
        #expect(throws: ClaudeRecipeImprovement.ImprovementError.wrongVariantOf(expected: original.id, found: nil)) {
            try ClaudeRecipeImprovement.improvement(
                fromResponse: try response(json), original: original, variantID: id, profile: profile)
        }
    }

    @Test func rejectsAnUnusedIngredientAndAWrongID() throws {
        let original = try original()
        let id = RecipeID("\(original.id.rawValue)-v1")
        var json = answer(echoing: original, id: id)
        var steps = try #require(json["steps"] as? [[String: Any]])
        for index in steps.indices { steps[index]["ingredientIndexes"] = [Int]() }
        steps[0]["ingredientIndexes"] = [0]
        json["steps"] = steps
        #expect {
            try ClaudeRecipeImprovement.improvement(
                fromResponse: try response(json), original: original, variantID: id, profile: profile)
        } throws: { error in
            guard case ClaudeRecipeImprovement.ImprovementError.unusedIngredients = error else { return false }
            return true
        }

        let wrong = answer(echoing: original, id: "anders")
        #expect(throws: ClaudeRecipeImprovement.ImprovementError.wrongID(expected: id, found: "anders")) {
            try ClaudeRecipeImprovement.improvement(
                fromResponse: try response(wrong), original: original, variantID: id, profile: profile)
        }
    }

    @Test func newIngredientsGetFreshIds() throws {
        let original = try original()
        let id = RecipeID("\(original.id.rawValue)-v1")
        var json = answer(echoing: original, id: id)
        var ingredients = try #require(json["ingredients"] as? [[String: Any]])
        ingredients[0]["id"] = NSNull()
        json["ingredients"] = ingredients
        let result = try ClaudeRecipeImprovement.improvement(
            fromResponse: try response(json), original: original, variantID: id, profile: profile)
        let ids = result.recipe.ingredients.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(Array(ids.dropFirst()) == Array(original.ingredients.map(\.id).dropFirst()))
    }

    @Test func feedbackCollectsEveryNoteAndTheLatestRating() {
        var log = CookLog()
        let recipe = RecipeID("suppe")
        log.record(recipe, at: Date(timeIntervalSince1970: 0), rating: 4, note: "Zu salzig")
        log.record(recipe, at: Date(timeIntervalSince1970: 86_400), rating: 2)
        log.record(recipe, at: Date(timeIntervalSince1970: 172_800), note: "Linsen zu weich")
        let feedback = RecipeFeedback(log: log, recipe: recipe)
        #expect(feedback.latestRating == 2)
        #expect(feedback.notes.map(\.text) == ["Zu salzig", "Linsen zu weich"])
        #expect(feedback.isActionable)
        #expect(feedback.promptText.contains("Zu salzig") && feedback.promptText.contains("2 von 5"))

        var good = CookLog()
        good.record(recipe, at: .now, rating: 5)
        #expect(!RecipeFeedback(log: good, recipe: recipe).isActionable)
        #expect(!RecipeFeedback(log: CookLog(), recipe: recipe).isActionable)
    }

    @Test func variantIDsCountUp() {
        let id = RecipeID("suppe")
        #expect(ClaudeRecipeImprovement.variantID(for: id, taken: ["suppe-v1", "suppe-v2"]) == "suppe-v3")
    }

    @Test func requestCarriesRecipeFeedbackAndLimits() throws {
        let original = try original()
        let feedback = RecipeFeedback(latestRating: 2, notes: [.init(cookedAt: .now, rating: 2, text: "Zu fad")])
        let body = try ClaudeRecipeImprovement.requestBody(
            recipe: original, feedback: feedback, variantID: "x-v1", profile: profile)
        let text = String(decoding: body, as: UTF8.self)
        #expect(text.contains("Zu fad"))
        #expect(text.contains("x-v1"))
        #expect(text.contains("\(profile.temperatureRange.upperBound) °C"))
        #expect(text.contains(ClaudeRecipeImport.model))
    }
}

extension RecipeImprovementTests {
    @Test func listsChangedStepsAndIngredients() throws {
        let original = try original()
        var recipe = original
        recipe.steps[0].text = "Anders."
        recipe.ingredients.removeLast()
        let changes = RecipeImprovement(recipe: recipe, summary: "s", warnings: []).changes(from: original)
        #expect(changes.count == 2)
        #expect(changes.contains(.stepChanged(old: original.steps[0], new: recipe.steps[0])))
        #expect(changes.contains(.ingredientRemoved(original.ingredients.last!)))
    }
}
