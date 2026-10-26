import Foundation
import Testing

@testable import KitchenCore

@Suite("Recipe rewrite")
struct RecipeRewriteTests {
    private static let quote = "Pflanzliche Öle bevorzugen"
    // Force-try is fine in a test fixture: a broken bundled catalog fails every test anyway.
    private static let catalog = try! FoodCatalog.bundled()

    private static func rule(
        _ id: SwapRuleID, from: FoodID, to: FoodID, share: Double = 1, ratio: Double = 1,
        extra: Duration = .zero, water: Double = 0, note: String? = nil
    ) -> SwapRule {
        SwapRule(
            id: id, from: from, to: to, toName: "Neu \(to)", share: share, ratio: ratio, extraTime: extra,
            extraWaterPerGram: water, stepNote: note, sourceID: "dge-2024", quote: quote)
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
        let rewrite = Self.recipe.rewritten(for: Self.goal, catalog: Self.catalog)
        let rice = try #require(rewrite.recipe.ingredient("reis"))
        #expect(rice.food == "brown-rice" && rice.name == "Neu brown-rice")
        #expect(rice.amount == .measured(200, .gram))
        #expect(rice.substitutes == [Substitute(name: "Basmatireis", ratio: 1, note: "Original")])
        let step = rewrite.recipe.steps[1]
        #expect(step.setting?.duration == .seconds(1980))
        #expect(step.note == "Deckel zu. Länger garen.")
        #expect(rewrite.recipe.totalMinutes == 45)
        #expect(rewrite.recipe.id == "pilaw-balanced" && !rewrite.recipe.verified)
        #expect(rewrite.recipe.variantOf == "pilaw")
    }

    @Test func partialSwapSplitsTheAmountAndJoinsTheSameSteps() throws {
        let rewrite = Self.recipe.rewritten(for: Self.goal, catalog: Self.catalog)
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
        let oil = try #require(Self.recipe.rewritten(for: goal, catalog: Self.catalog).recipe.ingredient("ghee"))
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
        let rewrite = Self.recipe.rewritten(for: Self.goal, catalog: Self.catalog)
        for id: IngredientID in ["zwiebel", "kreuzkuemmel", "wasser"] {
            #expect(rewrite.recipe.ingredient(id) == Self.recipe.ingredient(id), "\(id)")
        }
    }

    @Test func skipsASwapThatWouldExceedTheDeviceTimeLimit() {
        var recipe = Self.recipe
        recipe.steps[1].setting?.duration = .seconds(95 * 60)
        let rewrite = recipe.rewritten(for: Self.goal, catalog: Self.catalog)
        #expect(rewrite.recipe.ingredient("reis")?.food == "white-rice")
        #expect(
            rewrite.skipped == [SkippedSwap(rule: "brown-rice", ingredient: "reis", reason: .exceedsMaxDuration("s2"))])
    }

    @Test func skipsAPartialSwapOfAnAmountToTaste() {
        var recipe = Self.recipe
        recipe.ingredients[1].amount = .toTaste
        let rewrite = recipe.rewritten(for: Self.goal, catalog: Self.catalog)
        #expect(rewrite.recipe.ingredient("ghee")?.amount == .toTaste)
        #expect(rewrite.skipped.map(\.reason) == [.amountToTaste])
    }

    @Test func anOfferKeepsTheIngredientAndPutsTheAlternativeFirst() {
        var offer = Self.rule("cumin-alternative", from: "cumin", to: "coriander-ground", note: "milder")
        offer.offer = true
        var recipe = Self.recipe
        recipe.ingredients[3].eaten = false
        recipe.ingredients[3].substitutes = [Substitute(name: "Kümmel")]
        let goal = RewriteGoal(id: "vegetarian", rules: [offer])
        let rewrite = recipe.rewritten(for: goal, catalog: Self.catalog)
        let cumin = rewrite.recipe.ingredient("kreuzkuemmel")
        #expect(cumin?.food == "cumin" && cumin?.amount == .measured(1, .teaspoon))
        #expect(cumin?.substitutes.map(\.name) == ["Neu coriander-ground", "Kümmel"])
        #expect(cumin?.substitutes.first?.note == "milder")
        #expect(
            rewrite.changes == [
                RecipeChange(
                    rule: "cumin-alternative", ingredient: "kreuzkuemmel", newIngredient: "kreuzkuemmel", isOffer: true)
            ])
        // Offering twice does not list the alternative twice.
        var twice = rewrite.recipe
        twice.variantOf = nil
        #expect(
            twice.rewritten(for: goal, catalog: Self.catalog).recipe.ingredient("kreuzkuemmel")?.substitutes.count == 2)
    }

    @Test func offersMayNameSeasoningsWithoutImproving() {
        var offer = Self.rule("fish-sauce-alternative", from: "fish-sauce", to: "soy-sauce")
        offer.offer = true
        let rules = RewriteRules(goals: [RewriteGoal(id: "vegetarian", rules: [offer])])
        #expect(rules.issues(in: Self.catalog).isEmpty)
        offer.offer = false
        let swap = RewriteRules(goals: [RewriteGoal(id: "vegetarian", rules: [offer])])
        #expect(
            swap.issues(in: Self.catalog).contains(.protectedFood(rule: "fish-sauce-alternative", food: "fish-sauce")))
    }

    @Test func vegetarianSwapsMeatAndOffersAlternativesForFishAndAnimalSeasonings() throws {
        let advisor = try HealthAdvisor.bundled()
        let recipes = try RecipeLibrary.bundled()
        let meat = try #require(recipes.first { $0.id == "pad-krapow-gai" })
        let variant = try #require(advisor.variant(of: meat, for: RewriteGoal.vegetarian))
        #expect(variant.recipe.ingredients.allSatisfy { $0.food != "chicken-thigh" })
        #expect(variant.recipe.ingredients.contains { $0.food == "fish-sauce" })
        #expect(variant.changes.contains { $0.change.isOffer && $0.newName == "Helle Sojasauce mit etwas Miso" })
        let fish = try #require(recipes.first { $0.id == "gedaempfter-wolfsbarsch" })
        let fishVariant = try #require(advisor.variantRecipe(of: fish, for: RewriteGoal.vegetarian))
        #expect(fishVariant.ingredients.contains { $0.food == "sea-bass" })
        #expect(fishVariant.ingredients.first { $0.food == "sea-bass" }?.substitutes.first?.name == "Tofu, fest")
    }

    @Test func ingredientsThatAreNotEatenAreNotSwapped() {
        var recipe = Self.recipe
        recipe.ingredients[2].eaten = false
        #expect(recipe.rewritten(for: Self.goal, catalog: Self.catalog).changes.map(\.rule) == ["half-ghee"])
    }

    @Test func everyVariantPassesDeviceValidationAndKeepsSeasonings() throws {
        let rules = try RewriteRules.bundled()
        #expect(rules.goals.count == 5)
        for goal in try rules.goals.map({ try #require(rules.resolved($0.id)) }) {
            try checkVariants(for: goal)
        }
    }

    private func checkVariants(for goal: RewriteGoal) throws {
        for recipe in try RecipeLibrary.bundled() + [Self.recipe] {
            let variant = recipe.rewritten(for: goal, catalog: Self.catalog).recipe
            let errors = DeviceProfile.omniCook.validate(variant).filter { $0.severity == .error }
            #expect(errors.isEmpty, "\(recipe.id) \(goal.id): \(errors)")
            for ingredient in recipe.ingredients {
                guard let food = Self.catalog.food(for: ingredient), food.role == .seasoning || food.role == .aromatic
                else { continue }
                let after = try #require(variant.ingredient(ingredient.id), "\(recipe.id) lost \(ingredient.id)")
                // Only the sodium criterion may turn a seasoning into its declared low-sodium version.
                let lowSodium =
                    goal.criterion == .sodium
                    && after.food.flatMap(Self.catalog.food)?.lowSodiumVersionOf == food.id
                    && after.amount == ingredient.amount
                // An offer only adds an alternative to the substitutes; food and amount stay.
                let unchanged = after.food == ingredient.food && after.amount == ingredient.amount
                #expect(unchanged || lowSodium, "\(recipe.id) \(goal.id): \(ingredient.id)")
            }
        }
    }

    @Test func bloodPressureLowersSodiumOfTheBundledSalmonAndLentilStew() throws {
        let goal = try #require(try RewriteRules.bundled().resolved(RewriteGoal.bloodPressure))
        for id: RecipeID in ["ingwer-lachs-pak-choi", "zitronen-linsen-eintopf"] {
            let recipe = try #require(try RecipeLibrary.bundled().first { $0.id == id })
            let rewrite = recipe.rewritten(for: goal, catalog: Self.catalog)
            #expect(!rewrite.changes.isEmpty, "\(id)")
            #expect(
                Self.catalog.nutritionPerServing(of: rewrite.recipe).sodiumMilligrams
                    < Self.catalog.nutritionPerServing(of: recipe).sodiumMilligrams, "\(id)")
        }
    }

    @Test func weightLossLowersEnergyOfTheBundledCurry() throws {
        let goal = try #require(try RewriteRules.bundled().resolved(RewriteGoal.weightLoss))
        let recipe = try #require(try RecipeLibrary.bundled().first { $0.id == "kichererbsen-spinat-curry" })
        let variant = recipe.rewritten(for: goal, catalog: Self.catalog).recipe
        #expect(variant.ingredient("kokosmilch")?.amount == .measured(100, .gram))
        #expect(
            Self.catalog.nutritionPerServing(of: variant).kcal < Self.catalog.nutritionPerServing(of: recipe).kcal)
        #expect(goal.notes.count == 1)
        #expect(!goal.rules.contains { $0.id == "brown-rice" })
    }

    @Test func resolvedGoalPutsItsOwnRulesFirstAndInheritsTheRest() throws {
        let rules = try RewriteRules.bundled()
        let bloodPressure = try #require(rules.resolved(RewriteGoal.bloodPressure))
        #expect(bloodPressure.rules.prefix(2).map(\.id) == ["low-sodium-soy-sauce", "half-broth-water"])
        #expect(bloodPressure.rules.contains { $0.id == "brown-rice" })
        #expect(bloodPressure.extends == nil)
        let lowCarb = try #require(rules.resolved(RewriteGoal.lowCarb))
        #expect(!lowCarb.rules.contains { $0.id == "brown-rice" })
        #expect(lowCarb.notes.count == 1)
    }

    @Test func piecesOfAFoodWithoutPieceWeightBecomeGrams() throws {
        var recipe = Self.recipe
        recipe.ingredients[2] = Ingredient(
            id: "reis", name: "Kartoffeln", amount: .measured(3, .piece), food: "potato")
        let goal = RewriteGoal(id: "g", rules: [Self.rule("p", from: "potato", to: "cauliflower")])
        let swapped = try #require(recipe.rewritten(for: goal, catalog: Self.catalog).recipe.ingredient("reis"))
        #expect(swapped.amount == .measured(450, .gram))
        #expect(swapped.substitutions(from: 2, to: 2).first?.amount == .measured(450, .gram))
    }

    @Test func inheritedRulesMayNotWorsenTheInheritingGoal() {
        let rules = RewriteRules(goals: [
            RewriteGoal(id: "base", rules: [Self.rule("rice", from: "white-rice", to: "brown-rice")]),
            RewriteGoal(id: "lean", criterion: .energyDensity, extends: "base", rules: []),
            RewriteGoal(id: "salt", criterion: .sodium, extends: "base", rules: []),
        ])
        #expect(rules.issues(in: Self.catalog) == [.inheritedRuleWorsens(goal: "lean", rule: "rice")])
    }

    @Test func resolvingAnUnknownBaseOrACycleFails() {
        let rules = RewriteRules(goals: [
            RewriteGoal(id: "a", extends: "b", rules: []), RewriteGoal(id: "b", extends: "a", rules: []),
            RewriteGoal(id: "c", extends: "missing", rules: []),
        ])
        #expect(rules.resolved("a") == nil && rules.resolved("c") == nil && rules.resolved("nothing") == nil)
        #expect(
            rules.issues(in: Self.catalog) == [.unresolvableGoal("a"), .unresolvableGoal("b"), .unresolvableGoal("c")])
    }

    @Test func criteriaDecideWhatCountsAsAnImprovement() {
        let rules = RewriteRules(goals: [
            RewriteGoal(
                id: "sodium", criterion: .sodium,
                rules: [
                    Self.rule("soy", from: "soy-sauce", to: "low-sodium-soy-sauce"),
                    Self.rule("spice", from: "cumin", to: "turmeric"),
                ]),
            RewriteGoal(
                id: "rank", rules: [Self.rule("soy-rank", from: "soy-sauce", to: "low-sodium-soy-sauce")]),
            RewriteGoal(
                id: "energy", criterion: .energyDensity,
                rules: [
                    Self.rule("more", from: "cauliflower", to: "potato"),
                    Self.rule("blend", from: "potato", to: "garam-masala"),
                ]),
            RewriteGoal(
                id: "carbs", criterion: .carbohydrate,
                rules: [Self.rule("to-meat", from: "potato", to: "salmon")]),
        ])
        #expect(
            rules.issues(in: Self.catalog) == [
                .protectedFood(rule: "spice", food: "cumin"), .protectedFood(rule: "spice", food: "turmeric"),
                .protectedFood(rule: "soy-rank", food: "soy-sauce"),
                .protectedFood(rule: "soy-rank", food: "low-sodium-soy-sauce"), .notImproving("soy-rank"),
                .notImproving("more"), .protectedFood(rule: "blend", food: "garam-masala"),
                .missingNutrients(rule: "blend", food: "garam-masala"),
            ])
    }

    @Test func reportsGoalNotesWithoutSourceOrText() {
        let rules = RewriteRules(goals: [
            RewriteGoal(
                id: "g", rules: [],
                notes: [
                    GoalNote(text: "", sourceID: "dge-2024", quote: "q"),
                    GoalNote(text: "t", sourceID: "ghost", quote: "q"),
                ])
        ])
        #expect(rules.issues(in: Self.catalog) == [.emptyNote("g"), .unknownNoteSource(goal: "g", source: "ghost")])
    }

    @Test func balancedVariantHasMoreWholeGrainAndLessSaturatedFat() throws {
        let catalog = Self.catalog
        let balanced = try #require(try RewriteRules.bundled().resolved(RewriteGoal.balanced))
        let variant = Self.recipe.rewritten(for: balanced, catalog: catalog).recipe
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
                    Self.rule("same", from: "ghee", to: "butter"),
                    Self.rule("ghost", from: "nothing", to: "olive-oil"),
                    Self.rule("bad", from: "ghee", to: "olive-oil", share: 1.5),
                    Self.rule("bad", from: "butter", to: "olive-oil"),
                ]),
            RewriteGoal(id: "g", rules: []),
        ])
        #expect(
            rules.issues(in: catalog) == [
                .protectedFood(rule: "spice", food: "cumin"), .protectedFood(rule: "spice", food: "turmeric"),
                .notImproving("spice"),
                .notImproving("worse"), .notImproving("same"), .unknownFood(rule: "ghost", food: "nothing"),
                .invalidRule("bad"),
                .duplicateRule(goal: "g", rule: "bad"), .duplicateGoal("g"),
            ])
    }

    @Test func extraTimeGoesOnceOntoTheLongestHeatedStepAfterTheIngredientIsAdded() {
        var recipe = Self.recipe
        recipe.steps[0].ingredientIDs.append("reis")
        recipe.steps[1].ingredientIDs.removeAll { $0 == "reis" }
        let rewrite = recipe.rewritten(for: Self.goal, catalog: Self.catalog)
        #expect(rewrite.recipe.steps[0].setting?.duration == .seconds(180))
        #expect(rewrite.recipe.steps[1].setting?.duration == .seconds(1980))
        #expect(rewrite.recipe.steps[1].note == "Deckel zu. Länger garen.")
        #expect(rewrite.recipe.totalMinutes == 45)
    }

    @Test func extraTimeStopsAtAFreshPot() {
        var recipe = Self.recipe
        recipe.steps[0].ingredientIDs.append("reis")
        recipe.steps[1].freshPot = true
        let rewrite = recipe.rewritten(for: Self.goal, catalog: Self.catalog)
        #expect(rewrite.recipe.steps[0].setting?.duration == .seconds(1080))
        #expect(rewrite.recipe.steps[1].setting?.duration == .seconds(1080))
    }

    @Test func spoonAmountsAreConvertedByWeight() throws {
        var recipe = Self.recipe
        recipe.ingredients[1] = Ingredient(
            id: "ghee", name: "Butter", amount: .measured(2, .tablespoon), food: "butter",
            substitutes: [Substitute(name: "Margarine")])
        let goal = RewriteGoal(
            id: "g", rules: [Self.rule("butter", from: "butter", to: "olive-oil", ratio: 0.8)])
        let oil = try #require(recipe.rewritten(for: goal, catalog: Self.catalog).recipe.ingredient("ghee"))
        let grams = try #require(Self.catalog.food("olive-oil")?.grams(of: oil.amount))
        #expect(abs(grams - 2 * 14 * 0.8) < 0.0001)
        #expect(oil.substitutes.map(\.name) == ["Butter", "Margarine"])
    }

    @Test func aVariantIsNotRewrittenAgain() {
        let variant = Self.recipe.rewritten(for: Self.goal, catalog: Self.catalog).recipe
        let again = variant.rewritten(for: Self.goal, catalog: Self.catalog)
        #expect(again.recipe == variant && again.changes.isEmpty)
    }

    @Test func partialSwapPicksAFreeIngredientID() {
        var recipe = Self.recipe
        recipe.ingredients.append(Ingredient(id: "ghee-half-ghee", name: "Schon da", amount: .toTaste))
        let rewrite = recipe.rewritten(for: Self.goal, catalog: Self.catalog)
        #expect(rewrite.changes.first?.newIngredient == "ghee-half-ghee-2")
    }

    @Test func extraWaterGoesToTheWaterThatCooksTheNewFood() {
        let goal = RewriteGoal(
            id: "g", rules: [Self.rule("rice", from: "white-rice", to: "brown-rice", water: 0.5)])
        let rewrite = Self.recipe.rewritten(for: goal, catalog: Self.catalog)
        #expect(rewrite.recipe.ingredient("wasser")?.amount == .measured(500, .gram))
    }

    @Test func extraWaterFindsWaterAddedEarlierInTheSamePot() {
        var recipe = Self.recipe
        recipe.steps[0].ingredientIDs.append("wasser")
        recipe.steps[1].ingredientIDs.removeAll { $0 == "wasser" }
        let goal = RewriteGoal(
            id: "g", rules: [Self.rule("rice", from: "white-rice", to: "brown-rice", water: 0.5)])
        #expect(
            recipe.rewritten(for: goal, catalog: Self.catalog).recipe.ingredient("wasser")?.amount
                == .measured(500, .gram))
        recipe.steps[1].freshPot = true
        #expect(
            recipe.rewritten(for: goal, catalog: Self.catalog).recipe.ingredient("wasser")?.amount
                == .measured(400, .gram))
    }

    @Test func rulesRoundTripThroughJSON() throws {
        let rules = RewriteRules(goals: [Self.goal])
        let decoded = try RewriteRules.decode(JSONEncoder().encode(rules))
        #expect(decoded == rules)
    }
}
