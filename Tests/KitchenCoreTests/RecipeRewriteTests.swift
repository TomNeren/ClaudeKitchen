import Foundation
import Testing

@testable import KitchenCore

@Suite("Recipe rewrite")
struct RecipeRewriteTests {
    private static let quote = "Pflanzliche Öle bevorzugen"

    private static func rule(
        _ id: SwapRuleID, from: FoodID, to: FoodID, share: Double = 1, ratio: Double = 1,
        extra: Duration = .zero, note: String? = nil
    ) -> SwapRule {
        SwapRule(
            id: id, from: from, to: to, toName: "Neu \(to)", share: share, ratio: ratio, extraTime: extra,
            stepNote: note, sourceID: "dge-2024", quote: quote)
    }

    private static let recipe = Recipe(
        id: "pilaw", name: "Pilaw", tag: "", baseServings: 2, totalMinutes: 30,
        ingredients: [
            Ingredient(id: "zwiebel", name: "Zwiebel", amount: .measured(1, .piece), food: "onion"),
            Ingredient(id: "ghee", name: "Ghee", amount: .measured(30, .gram), food: "ghee"),
            Ingredient(id: "reis", name: "Basmatireis", amount: .measured(200, .gram), food: "white-rice"),
            Ingredient(id: "kreuzkuemmel", name: "Kreuzkümmel", amount: .measured(1, .teaspoon), food: "cumin"),
            Ingredient(id: "wasser", name: "Wasser", amount: .measured(400, .gram), food: "water"),
        ],
        steps: [
            Step(
                id: "s1", phase: "Anschwitzen", text: "Zwiebel und Ghee", ingredientIDs: ["zwiebel", "ghee"],
                setting: DeviceSetting(heat: .celsius(120), rotation: .reverse(speed: 1), duration: .seconds(180))),
            Step(
                id: "s2", phase: "Garen", text: "Reis und Wasser", note: "Deckel zu.",
                ingredientIDs: ["reis", "kreuzkuemmel", "wasser"],
                setting: DeviceSetting(heat: .celsius(100), rotation: .reverse(speed: 1), duration: .seconds(1080))),
        ])

    private static let goal = RewriteGoal(
        id: "balanced",
        rules: [
            rule("brown-rice", from: "white-rice", to: "brown-rice", extra: .seconds(900), note: "Länger garen."),
            rule("half-ghee", from: "ghee", to: "olive-oil", share: 0.5),
        ])

    @Test func fullSwapReplacesTheIngredientAndLengthensItsStep() throws {
        let rewrite = Self.recipe.rewritten(for: Self.goal)
        let rice = try #require(rewrite.recipe.ingredient("reis"))
        #expect(rice.food == "brown-rice" && rice.name == "Neu brown-rice")
        #expect(rice.amount == .measured(200, .gram))
        #expect(rice.substitutes == [Substitute(name: "Basmatireis", ratio: 1, note: "Original")])
        let step = rewrite.recipe.steps[1]
        #expect(step.setting?.duration == .seconds(1980))
        #expect(step.note == "Deckel zu. Länger garen.")
        #expect(rewrite.recipe.totalMinutes == 45)
        #expect(rewrite.recipe.id == "pilaw-balanced" && !rewrite.recipe.verified)
    }

    @Test func partialSwapSplitsTheAmountAndJoinsTheSameSteps() throws {
        let rewrite = Self.recipe.rewritten(for: Self.goal)
        #expect(rewrite.recipe.ingredient("ghee")?.amount == .measured(15, .gram))
        let oil = try #require(rewrite.recipe.ingredient("ghee-half-ghee"))
        #expect(oil.food == "olive-oil" && oil.amount == .measured(15, .gram))
        #expect(rewrite.recipe.ingredients.map(\.id)[1...2] == ["ghee", "ghee-half-ghee"])
        #expect(rewrite.recipe.steps[0].ingredientIDs == ["zwiebel", "ghee", "ghee-half-ghee"])
        #expect(
            rewrite.changes == [
                RecipeChange(rule: "half-ghee", ingredient: "ghee", newIngredient: "ghee-half-ghee"),
                RecipeChange(rule: "brown-rice", ingredient: "reis", newIngredient: "reis"),
            ])
    }

    @Test func ratioScalesTheNewFoodAndTheSubstituteLeadsBack() throws {
        let goal = RewriteGoal(id: "g", rules: [Self.rule("butter", from: "ghee", to: "olive-oil", ratio: 0.8)])
        let oil = try #require(Self.recipe.rewritten(for: goal).recipe.ingredient("ghee"))
        #expect(oil.amount == .measured(24, .gram))
        let back = oil.substitutions(from: 2, to: 2)
        #expect(back.count == 1)
        if case .measured(let grams, .gram) = back[0].amount {
            #expect(abs(grams - 30) < 0.0001)
        } else {
            Issue.record("substitute amount is not in grams")
        }
    }

    @Test func seasoningsAromaticsAndOtherIngredientsStayUntouched() {
        let rewrite = Self.recipe.rewritten(for: Self.goal)
        for id: IngredientID in ["zwiebel", "kreuzkuemmel", "wasser"] {
            #expect(rewrite.recipe.ingredient(id) == Self.recipe.ingredient(id), "\(id)")
        }
    }

    @Test func skipsASwapThatWouldExceedTheDeviceTimeLimit() {
        var recipe = Self.recipe
        recipe.steps[1].setting?.duration = .seconds(95 * 60)
        let rewrite = recipe.rewritten(for: Self.goal)
        #expect(rewrite.recipe.ingredient("reis")?.food == "white-rice")
        #expect(
            rewrite.skipped == [SkippedSwap(rule: "brown-rice", ingredient: "reis", reason: .exceedsMaxDuration("s2"))])
    }

    @Test func skipsAPartialSwapOfAnAmountToTaste() {
        var recipe = Self.recipe
        recipe.ingredients[1].amount = .toTaste
        let rewrite = recipe.rewritten(for: Self.goal)
        #expect(rewrite.recipe.ingredient("ghee")?.amount == .toTaste)
        #expect(rewrite.skipped.map(\.reason) == [.amountToTaste])
    }

    @Test func ingredientsThatAreNotEatenAreNotSwapped() {
        var recipe = Self.recipe
        recipe.ingredients[2].eaten = false
        #expect(recipe.rewritten(for: Self.goal).changes.map(\.rule) == ["half-ghee"])
    }

    @Test func variantPassesDeviceValidationAndKeepsSeasoningsForEveryBundledRecipe() throws {
        let catalog = try FoodCatalog.bundled()
        let goals = try RewriteRules.bundled().goals
        for recipe in try RecipeLibrary.bundled() + [Self.recipe] {
            for goal in goals {
                let variant = recipe.rewritten(for: goal).recipe
                let errors = DeviceProfile.omniCook.validate(variant).filter { $0.severity == .error }
                #expect(errors.isEmpty, "\(recipe.id) \(goal.id): \(errors)")
                for ingredient in recipe.ingredients {
                    guard let role = catalog.food(for: ingredient)?.role, role == .seasoning || role == .aromatic
                    else { continue }
                    #expect(variant.ingredient(ingredient.id) == ingredient, "\(recipe.id): \(ingredient.id)")
                }
            }
        }
    }

    @Test func balancedVariantHasMoreWholeGrainAndLessSaturatedFat() throws {
        let catalog = try FoodCatalog.bundled()
        let balanced = try #require(try RewriteRules.bundled().goal(RewriteGoal.balanced))
        let variant = Self.recipe.rewritten(for: balanced).recipe
        let before = catalog.groupGramsPerServing(of: Self.recipe)
        let after = catalog.groupGramsPerServing(of: variant)
        #expect(before["whole-grains"] == nil && after["whole-grains"] == 100)
        #expect(after["saturated-fats", default: 0] < before["saturated-fats", default: 0])
        #expect(
            catalog.nutritionPerServing(of: variant).saturatedFat
                < catalog.nutritionPerServing(of: Self.recipe).saturatedFat)
    }

    @Test func bundledRulesAreConsistentWithTheCatalog() throws {
        let rules = try RewriteRules.bundled()
        let issues = rules.issues(in: try FoodCatalog.bundled())
        #expect(issues.isEmpty, "\(issues)")
        #expect(rules.goal(RewriteGoal.balanced) != nil)
    }

    @Test func reportsInvalidRules() throws {
        let catalog = try FoodCatalog.bundled()
        let rules = RewriteRules(goals: [
            RewriteGoal(
                id: "g",
                rules: [
                    Self.rule("spice", from: "cumin", to: "turmeric"),
                    Self.rule("worse", from: "olive-oil", to: "butter"),
                    Self.rule("ghost", from: "nothing", to: "olive-oil"),
                    Self.rule("bad", from: "ghee", to: "olive-oil", share: 1.5),
                    Self.rule("bad", from: "butter", to: "olive-oil"),
                ]),
            RewriteGoal(id: "g", rules: []),
        ])
        #expect(
            rules.issues(in: catalog) == [
                .protectedFood(rule: "spice", food: "cumin"), .protectedFood(rule: "spice", food: "turmeric"),
                .worseningSwap("worse"), .unknownFood(rule: "ghost", food: "nothing"), .invalidRule("bad"),
                .duplicateRule(goal: "g", rule: "bad"), .duplicateGoal("g"),
            ])
    }

    @Test func rulesRoundTripThroughJSON() throws {
        let rules = RewriteRules(goals: [Self.goal])
        let decoded = try RewriteRules.decode(JSONEncoder().encode(rules))
        #expect(decoded == rules)
    }
}
