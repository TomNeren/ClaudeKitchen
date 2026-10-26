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
                accessory: nil, freshPot: false),
            .init(
                phase: "Köcheln", text: "Tomaten und Brühe zugeben, köcheln.", note: nil, ingredientIndexes: [1, 2, 3],
                setting: .init(program: "manual", celsius: 100, steam: false, speed: 1, reverse: true, seconds: 900),
                accessory: nil, freshPot: false),
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

    @Test func schemaListsPropertiesInWritingOrderAndRequiresAll() throws {
        let members = try #require(ClaudeRecipeImport.schema.members)
        let properties = try #require(members.first { $0.0 == "properties" }?.1.members)
        #expect(properties.map(\.0) == ["name", "tag", "baseServings", "totalMinutes", "ingredients", "steps"])
        #expect(members.first { $0.0 == "additionalProperties" }?.1 == .bool(false))
        #expect(members.first { $0.0 == "required" }?.1 == .array(properties.map { .string($0.0) }))
        let body = try ClaudeRecipeImport.requestBody(recipeText: "x", profile: .omniCook)
        let json = String(decoding: body, as: UTF8.self)
        let phase = try #require(json.range(of: "\"phase\""))
        let freshPot = try #require(json.range(of: "\"freshPot\""))
        #expect(phase.lowerBound < freshPot.lowerBound)
    }

    @Test func encodingKeepsKeyOrderAndEscapes() throws {
        let keys = (0..<40).map { "k\($0)" }
        let value: JSONValue = .object(
            keys.map { ($0, .null) } + [
                ("text", .string("a\"b\n")), ("list", .array([.integer(1), .bool(true), .number(0.5)])),
            ])
        let json = String(decoding: try value.encoded(), as: UTF8.self)
        let expectedKeys = keys.map { "\"\($0)\":null" }.joined(separator: ",")
        #expect(json == "{\(expectedKeys),\"text\":\"a\\\"b\\n\",\"list\":[1,true,0.5]}")
    }

    @Test func promptSaysIndexesCountFromZero() {
        let prompt = ClaudeRecipeImport.systemPrompt(for: .omniCook)
        #expect(prompt.contains("gezählt ab 0"))
        #expect(prompt.contains("g, Stk, Zehen, TL, EL, ml"))
    }

    @Test func countWithoutUnitIsPieces() throws {
        var eggs = draft
        eggs.ingredients[0] = .init(name: "Eier", quantity: 3, unit: nil, note: nil, scales: true)
        #expect(try eggs.recipe(id: "x").ingredient("eier")?.amount == .measured(3, .piece))
    }

    @Test func freshPotCarriesOver() throws {
        var curry = draft
        curry.steps[1].freshPot = true
        #expect(try curry.recipe(id: "x").steps[1].freshPot)
    }

    @Test func readsTheRecipeFromASuccessfulResponse() throws {
        let recipeJSON = String(decoding: try JSONEncoder().encode(draft), as: UTF8.self)
        let response = try JSONSerialization.data(withJSONObject: [
            "stop_reason": "end_turn",
            "content": [["type": "thinking", "thinking": ""], ["type": "text", "text": recipeJSON]],
        ])
        #expect(try ClaudeRecipeImport.draft(fromResponse: response) == draft)
        let recipe = try ClaudeRecipeImport.recipe(fromResponse: response, id: "neu")
        #expect(recipe.id == "neu")
        // Ingredients come back mapped to the bundled catalog by name.
        #expect(recipe.ingredients.map(\.food) == ["onion", "tomato", "vegetable-broth", "salt", "onion"])
        #expect(
            try ClaudeRecipeImport.recipe(fromResponse: response, id: "neu", catalog: nil).ingredients[0].food == nil)
    }

    @Test func gatewayErrorsBecomeHTTPStatus() {
        #expect(throws: ClaudeRecipeImport.ResponseError.http(status: 502)) {
            try ClaudeRecipeImport.draft(fromResponse: Data("<html>Bad Gateway</html>".utf8), status: 502)
        }
        #expect(throws: ClaudeRecipeImport.ResponseError.missingRecipe) {
            try ClaudeRecipeImport.draft(
                fromResponse: Data(#"{"stop_reason":"end_turn","content":[{"type":"text","text":"kein json"}]}"#.utf8))
        }
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
