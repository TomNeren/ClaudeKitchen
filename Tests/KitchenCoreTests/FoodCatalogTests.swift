import Foundation
import Testing

@testable import KitchenCore

@Suite("Food catalog")
struct FoodCatalogTests {
    @Test func bundledCatalogIsConsistent() throws {
        let catalog = try FoodCatalog.bundled()
        #expect(catalog.issues().isEmpty, "\(catalog.issues())")
        #expect(!catalog.foods.isEmpty)
    }

    @Test func everyIngredientOfEveryBundledRecipeIsMappedAndWeighable() throws {
        let catalog = try FoodCatalog.bundled()
        for recipe in try RecipeLibrary.bundled() {
            let issues = catalog.issues(in: recipe)
            #expect(issues.isEmpty, "\(recipe.id): \(issues)")
        }
    }

    @Test func reportsCatalogInconsistencies() {
        let catalog = FoodCatalog(
            sources: [EvidenceSource(id: "s", citation: "S", year: 2024)],
            groups: [
                FoodGroup(id: "g", name: "G", direction: .favorable, sourceIDs: ["missing"]),
                FoodGroup(id: "g", name: "G2", direction: .limit),
            ],
            foods: [
                Food(id: "f", name: "F", group: "nowhere", role: .seasoning),
                Food(
                    id: "f", name: "F2", group: "g", role: .seasoning, gramsPerUnit: [.piece: 0, .gram: 1, .clove: 3]),
            ])
        #expect(
            catalog.issues() == [
                .duplicateGroup("g"), .duplicateFood("f"),
                .unknownSource(group: "g", source: "missing"), .assessedWithoutSource("g"),
                .unknownGroup(food: "f", group: "nowhere"),
                .invalidWeight(food: "f", unit: .piece), .invalidWeight(food: "f", unit: .gram),
            ])
    }

    @Test func reportsUnmappedUnknownAndUnweighableIngredients() {
        let catalog = FoodCatalog(
            sources: [], groups: [FoodGroup(id: "veg", name: "Gemüse", direction: .notAssessed)],
            foods: [Food(id: "onion", name: "Zwiebel", group: "veg", role: .aromatic)])
        let recipe = Recipe(
            id: "r", name: "R", tag: "", baseServings: 2, totalMinutes: 10,
            ingredients: [
                Ingredient(id: "a", name: "A", amount: .measured(100, .gram)),
                Ingredient(id: "b", name: "B", amount: .measured(1, .gram), food: "ghost"),
                Ingredient(id: "c", name: "Zwiebel", amount: .measured(1, .piece), food: "onion"),
                Ingredient(id: "d", name: "Zwiebel", amount: .toTaste, food: "onion"),
            ],
            steps: [])
        #expect(
            catalog.issues(in: recipe) == [
                .unmappedIngredient("a"), .unknownFood(ingredient: "b", food: "ghost"),
                .missingWeight(ingredient: "c", unit: .piece),
            ])
    }

    @Test(arguments: [
        (Amount.measured(250, .gram), 250.0 as Double?),
        (.measured(2, .piece), 200),
        (.measured(1, .teaspoon), nil),
        (.toTaste, nil),
    ])
    func convertsAmountsToGrams(amount: Amount, grams: Double?) {
        let onion = Food(id: "onion", name: "Zwiebel", group: "veg", role: .aromatic, gramsPerUnit: [.piece: 100])
        #expect(onion.grams(of: amount) == grams)
    }

    @Test func foodRoundTripsThroughJSONWithUnitKeys() throws {
        let food = Food(id: "salt", name: "Salz", group: "salt", role: .seasoning, gramsPerUnit: [.teaspoon: 6])
        let json = try #require(String(data: JSONEncoder().encode(food), encoding: .utf8))
        #expect(json.contains("\"TL\":6"))
        #expect(try JSONDecoder().decode(Food.self, from: Data(json.utf8)) == food)
    }

    @Test func catalogWithoutTargetsDecodes() throws {
        let json = #"{"schemaVersion": 1, "sources": [], "groups": [], "foods": []}"#
        #expect(try FoodCatalog.decode(Data(json.utf8)).targets.isEmpty)
    }

    @Test func ingredientWithoutFoodStillDecodes() throws {
        let json = #"{"id": "x", "name": "X", "quantity": 5, "unit": "g"}"#
        let ingredient = try JSONDecoder().decode(Ingredient.self, from: Data(json.utf8))
        #expect(ingredient.food == nil)
    }

    @Test func rejectsNewerSchemaVersion() {
        let json = #"{"schemaVersion": 99, "sources": [], "groups": [], "foods": []}"#
        #expect(throws: FoodCatalog.LoadError.unsupportedSchemaVersion(99)) {
            try FoodCatalog.decode(Data(json.utf8))
        }
    }
}

@Suite("Evidence")
struct EvidenceTests {
    private static let source = EvidenceSource(id: "s", citation: "S", year: 2017)

    private static func catalog(groups: [FoodGroup], targets: [IntakeTarget] = []) -> FoodCatalog {
        FoodCatalog(sources: [source], groups: groups, foods: [], targets: targets)
    }

    private static func effect(_ rr: Double, _ lower: Double, _ upper: Double, quote: String = "q") -> EffectEstimate {
        EffectEstimate(
            outcome: .allCauseMortality, relativeRisk: rr, lower: lower, upper: upper, sourceID: "s", quote: quote)
    }

    @Test func bundledEffectsAreSignificantAndPointTheWayOfTheirGroup() throws {
        let catalog = try FoodCatalog.bundled()
        let groups = catalog.groups.filter { !$0.effects.isEmpty }
        #expect(
            Set(groups.map(\.id)) == [
                "whole-grains", "vegetables", "fruit", "nuts", "fish", "red-meat", "processed-meat",
            ])
        for group in groups {
            for effect in group.effects {
                #expect(effect.isSignificant, "\(group.id)")
                #expect(group.direction == (effect.relativeRisk < 1 ? .favorable : .limit), "\(group.id)")
            }
        }
    }

    @Test func bundledTargetsMatchTheDGEFigures() throws {
        let targets = try FoodCatalog.bundled().targets
        let meat = try #require(targets.first { $0.id == "meat" })
        #expect(meat.maximum == 300 && meat.measure == .grams && meat.period == .week)
        #expect(Set(meat.groups) == ["red-meat", "processed-meat", "poultry"])
        let fish = try #require(targets.first { $0.id == "fish" })
        #expect(fish.minimum == 1 && fish.maximum == 2 && fish.servingGrams == 120)
        let produce = try #require(targets.first { $0.id == "fruit-vegetables" })
        #expect(produce.minimum == 5 && produce.period == .day)
    }

    @Test(arguments: [
        (0.9, 0.8, 0.95, true),
        (1.1, 1.02, 1.2, true),
        (0.97, 0.9, 1.04, false),
    ])
    func significanceNeedsAnIntervalThatExcludesOne(rr: Double, lower: Double, upper: Double, significant: Bool) {
        #expect(Self.effect(rr, lower, upper).isSignificant == significant)
    }

    @Test func reportsInvalidAndContradictingEffects() {
        let catalog = Self.catalog(groups: [
            FoodGroup(
                id: "a", name: "A", direction: .favorable, sourceIDs: ["s"], effects: [Self.effect(1.2, 1.1, 1.3)]),
            FoodGroup(id: "b", name: "B", direction: .limit, sourceIDs: ["s"], effects: [Self.effect(0.8, 0.7, 0.9)]),
            FoodGroup(
                id: "c", name: "C", direction: .neutral, sourceIDs: ["s"], effects: [Self.effect(0.8, 0.85, 0.9)]),
            FoodGroup(
                id: "d", name: "D", direction: .neutral, sourceIDs: ["s"],
                effects: [Self.effect(0.8, 0.7, 0.9, quote: "")]),
            FoodGroup(
                id: "e", name: "E", direction: .neutral, sourceIDs: ["s"],
                effects: [
                    EffectEstimate(
                        outcome: .allCauseMortality, relativeRisk: 0.9, lower: 0.8, upper: 1, sourceID: "other",
                        quote: "q")
                ]),
            FoodGroup(id: "f", name: "F", direction: .neutral, sourceIDs: ["s"], effects: [Self.effect(1.2, 1.1, 1.3)]),
        ])
        #expect(
            catalog.issues() == [
                .effectContradictsDirection("a"), .effectContradictsDirection("b"), .invalidEffect("c"),
                .invalidEffect("d"), .uncitedEffectSource(group: "e", source: "other"),
                .effectContradictsDirection("f"),
            ])
    }

    @Test func reportsInvalidTargets() {
        let group = FoodGroup(id: "g", name: "G", direction: .neutral, sourceIDs: ["s"])
        func target(
            _ id: IntakeTargetID, min: Double? = nil, max: Double? = nil, groups: [FoodGroupID] = ["g"],
            source: SourceID = "s"
        ) -> IntakeTarget {
            IntakeTarget(
                id: id, groups: groups, measure: .grams, minimum: min, maximum: max, period: .week, sourceID: source,
                quote: "q")
        }
        let catalog = Self.catalog(
            groups: [group],
            targets: [
                target("ok", min: 1, max: 2), target("none"), target("reversed", min: 3, max: 2),
                target("zero", max: 0), target("ghost", max: 1, groups: ["nowhere"], source: "missing"),
                target("ok", max: 1),
                IntakeTarget(
                    id: "grams-with-serving", groups: ["g"], measure: .grams, maximum: 300, period: .week,
                    servingGrams: 120, sourceID: "s", quote: "q"),
            ])
        #expect(
            catalog.issues() == [
                .duplicateTarget("ok"), .invalidTarget("none"), .invalidTarget("reversed"), .invalidTarget("zero"),
                .unknownTargetGroup(target: "ghost", group: "nowhere"),
                .unknownTargetSource(target: "ghost", source: "missing"), .invalidTarget("grams-with-serving"),
            ])
    }
}
