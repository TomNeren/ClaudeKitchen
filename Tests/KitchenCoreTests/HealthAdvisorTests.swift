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

    @Test func goalWithoutMatchingRulesGivesAnUnchangedVariant() throws {
        let advisor = try HealthAdvisor.bundled()
        let recipe = try #require(try RecipeLibrary.bundled().first { $0.id == "ingwer-lachs-pak-choi" })
        let variant = try #require(advisor.variant(of: recipe, for: RewriteGoal.lowCarb))
        #expect(variant.changes.isEmpty)
        #expect(variant.recipe.ingredients == recipe.ingredients)
        #expect(variant.nutritionAfter == variant.nutritionBefore)
    }

    @Test func unknownGoalGivesNoVariant() throws {
        let advisor = try HealthAdvisor.bundled()
        let recipe = try #require(try RecipeLibrary.bundled().first)
        #expect(advisor.variant(of: recipe, for: "unknown") == nil)
    }
}
