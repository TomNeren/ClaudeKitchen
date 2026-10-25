import Foundation
import Testing

@testable import KitchenCore

@Suite("Recipe import")
struct RecipeImportTests {
    private let draft = RecipeDraft(
        name: "Tomatensuppe", tag: "Klassisch · Suppe", baseServings: 2, totalMinutes: 25,
        ingredients: [
            .init(name: "Zwiebel", quantity: 1, unit: "Stk", note: nil, scales: true),
            .init(name: "Tomaten", quantity: 800, unit: "g", note: "Dose", scales: true),
            .init(name: "Gemüsebrühe", quantity: 300, unit: "ml", note: nil, scales: true),
            .init(name: "Salz", quantity: nil, unit: nil, note: nil, scales: true),
            .init(name: "Zwiebel", quantity: 1, unit: "Stk", note: "rot", scales: true),
        ],
        steps: [
            .init(
                phase: "Zerkleinern", text: "Zwiebel 5 Sek zerkleinern.", note: nil, ingredientIndexes: [0, 4],
                setting: .init(program: "manual", celsius: nil, steam: false, speed: 5, reverse: false, seconds: 5),
                accessory: nil),
            .init(
                phase: "Köcheln", text: "Tomaten und Brühe zugeben, köcheln.", note: nil, ingredientIndexes: [1, 2, 3],
                setting: .init(program: "manual", celsius: 100, steam: false, speed: 1, reverse: true, seconds: 900),
                accessory: nil),
        ])

    @Test func convertsADraftIntoAValidRecipe() throws {
        let recipe = try draft.recipe(id: "tomatensuppe")
        #expect(recipe.ingredients.map(\.id.rawValue) == ["zwiebel", "tomaten", "gemusebruhe", "salz", "zwiebel-2"])
        #expect(recipe.ingredient("gemusebruhe")?.amount == .measured(300, .gram))
        #expect(recipe.ingredient("salz")?.amount == .toTaste)
        #expect(recipe.steps[0].ingredientIDs == ["zwiebel", "zwiebel-2"])
        #expect(
            recipe.steps[1].setting
                == DeviceSetting(heat: .celsius(100), rotation: .reverse(speed: 1), duration: .seconds(900)))
        #expect(!recipe.verified)
        #expect(DeviceProfile.omniCook.validate(recipe).isEmpty)
    }

    @Test func rejectsUnknownValues() {
        var badUnit = draft
        badUnit.ingredients[0].unit = "Tasse"
        #expect(throws: RecipeDraftError.unknownUnit(ingredient: "Zwiebel", unit: "Tasse")) {
            try badUnit.recipe(id: "x")
        }
        var badIndex = draft
        badIndex.steps[1].ingredientIndexes = [9]
        #expect(throws: RecipeDraftError.ingredientIndexOutOfRange(step: 2, index: 9)) { try badIndex.recipe(id: "x") }
        var badProgram = draft
        badProgram.steps[0].setting?.program = "grill"
        #expect(throws: RecipeDraftError.unknownProgram(step: 1, program: "grill")) { try badProgram.recipe(id: "x") }
    }

    @Test func steamSettingBecomesSteamHeat() throws {
        var steamed = draft
        steamed.steps[1].setting = .init(
            program: "steam", celsius: nil, steam: true, speed: nil, reverse: false, seconds: 600)
        steamed.steps[1].accessory = "steamer"
        let step = try steamed.recipe(id: "x").steps[1]
        #expect(step.setting == DeviceSetting(program: .steam, heat: .steam, duration: .seconds(600)))
        #expect(step.accessory == .steamer)
    }

    @Test func requestCarriesModelSchemaAndDeviceLimits() throws {
        let data = try ClaudeRecipeImport.requestBody(recipeText: "2 Tomaten", profile: .omniCook)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["model"] as? String == "claude-opus-5-5")
        #expect(body["fallbacks"] as? String == "default")
        let config = try #require(body["output_config"] as? [String: Any])
        #expect(config["effort"] as? String == "low")
        let format = try #require(config["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        let system = try #require(body["system"] as? String)
        #expect(system.contains("35 bis 180 °C"))
        #expect(system.contains("vorwärts 1 bis 10"))
        #expect(system.contains("höchstens 99 Minuten"))
        #expect(system.contains("2,2 l Füllmarke"))
        #expect(ClaudeRecipeImport.headers["anthropic-beta"] == "server-side-fallback-2026-07-01")
    }

    @Test func schemaRequiresEveryPropertyAndForbidsExtras() throws {
        let schema = ClaudeRecipeImport.schema
        #expect(schema["additionalProperties"] as? Bool == false)
        #expect(
            schema["required"] as? [String] == ["baseServings", "ingredients", "name", "steps", "tag", "totalMinutes"])
    }

    @Test func readsTheRecipeFromASuccessfulResponse() throws {
        let recipeJSON = String(decoding: try JSONEncoder().encode(draft), as: UTF8.self)
        let response = try JSONSerialization.data(withJSONObject: [
            "stop_reason": "end_turn",
            "content": [["type": "thinking", "thinking": ""], ["type": "text", "text": recipeJSON]],
        ])
        #expect(try ClaudeRecipeImport.draft(fromResponse: response) == draft)
    }

    @Test(arguments: [
        (#"{"stop_reason":"refusal","content":[]}"#, ClaudeRecipeImport.ResponseError.refusal),
        (#"{"stop_reason":"max_tokens","content":[{"type":"text","text":"{"}]}"#, .truncated),
        (#"{"stop_reason":"end_turn","content":[]}"#, .missingRecipe),
        (
            #"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#,
            .api(type: "authentication_error", message: "invalid x-api-key")
        ),
    ])
    func reportsProblemsInTheResponse(json: String, expected: ClaudeRecipeImport.ResponseError) {
        #expect(throws: expected) { try ClaudeRecipeImport.draft(fromResponse: Data(json.utf8)) }
    }
}
