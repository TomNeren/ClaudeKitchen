import Foundation
import Testing

@testable import KitchenCore

@Suite("Health advisor")
struct HealthAdvisorTests {
    @Test func bundledAdvisorOffersTheFourGoalsInFileOrder() throws {
        let advisor = try HealthAdvisor.bundled()
        #expect(advisor.goals == ["balanced", "blood-pressure", "weight-loss", "low-carb"])
    }

    @Test func variantResolvesChangesSourcesAndNutrition() throws {
        let advisor = try HealthAdvisor.bundled()
        let recipe = try #require(try RecipeLibrary.bundled().first { $0.id == "ingwer-lachs-pak-choi" })
        let variant = try #require(advisor.variant(of: recipe, for: RewriteGoal.bloodPressure))
        #expect(variant.recipe.id == "ingwer-lachs-pak-choi-blood-pressure")
        let soy = try #require(variant.changes.first { $0.rule.id == "low-sodium-soy-sauce" })
        #expect(soy.originalName == "Sojasauce" && soy.newName == "Sojasauce, salzreduziert")
        #expect(soy.source?.id == "sacks-2001")
        #expect(variant.notes.map(\.source?.id) == ["dge-salt"])
        #expect(variant.nutritionAfter.sodiumMilligrams < variant.nutritionBefore.sodiumMilligrams)
    }

    @Test func everyChangeOfEveryBundledVariantHasADetailWithASource() throws {
        let advisor = try HealthAdvisor.bundled()
        for recipe in try RecipeLibrary.bundled() {
            for goal in advisor.goals {
                let variant = try #require(advisor.variant(of: recipe, for: goal))
                #expect(variant.changes.count == variant.rewrite.changes.count, "\(recipe.id) \(goal)")
                #expect(variant.changes.allSatisfy { $0.source != nil }, "\(recipe.id) \(goal)")
                #expect(variant.recipe.variantOf == recipe.id)
                #expect(advisor.variantRecipe(of: recipe, for: goal) == variant.recipe)
            }
        }
    }

    @Test func aRuleIDThatRepeatsThroughExtendsIsReported() throws {
        let rule = SwapRule(
            id: "same", from: "white-rice", to: "brown-rice", toName: "Vollkornreis", sourceID: "dge-2024",
            quote: "q")
        let other = SwapRule(
            id: "same", from: "pasta", to: "whole-wheat-pasta", toName: "Vollkornnudeln", sourceID: "dge-2024",
            quote: "q")
        let rules = RewriteRules(goals: [
            RewriteGoal(id: "base", rules: [rule]), RewriteGoal(id: "child", extends: "base", rules: [other]),
        ])
        #expect(rules.issues(in: try FoodCatalog.bundled()) == [.duplicateRule(goal: "child", rule: "same")])
    }

    @Test func goalWithoutMatchingRulesGivesAnUnchangedVariant() throws {
        let advisor = try HealthAdvisor.bundled()
        let recipe = try #require(try RecipeLibrary.bundled().first { $0.id == "ingwer-lachs-pak-choi" })
        let variant = try #require(advisor.variant(of: recipe, for: RewriteGoal.lowCarb))
        #expect(variant.changes.isEmpty)
        #expect(variant.recipe.ingredients == recipe.ingredients)
        #expect(variant.nutritionAfter == variant.nutritionBefore)
    }

    @Test func balancedRewritesTheIndianRiceAndGhee() throws {
        let advisor = try HealthAdvisor.bundled()
        let recipes = try RecipeLibrary.bundled()
        let rice = try #require(recipes.first { $0.id == "jeera-reis" })
        let riceVariant = try #require(advisor.variant(of: rice, for: RewriteGoal.balanced))
        #expect(riceVariant.recipe.ingredient("reis")?.food == "brown-rice")
        #expect(riceVariant.recipe.steps.first { $0.id == "s3" }?.setting?.duration == .seconds(1980))
        #expect(riceVariant.recipe.ingredient("wasser")?.amount == .measured(440, .gram))
        let dal = try #require(recipes.first { $0.id == "dal-tadka" })
        let dalVariant = try #require(advisor.variant(of: dal, for: RewriteGoal.balanced))
        #expect(dalVariant.changes.map(\.rule.id) == ["half-ghee-to-olive-oil", "half-ghee-to-olive-oil"])
        #expect(dalVariant.nutritionAfter.saturatedFat < dalVariant.nutritionBefore.saturatedFat)
    }

    @Test func unknownGoalGivesNoVariant() throws {
        let advisor = try HealthAdvisor.bundled()
        let recipe = try #require(try RecipeLibrary.bundled().first)
        #expect(advisor.variant(of: recipe, for: "unknown") == nil)
    }
}
