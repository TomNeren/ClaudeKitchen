import Foundation
import Testing

@testable import KitchenCore

@Suite("Recipe editing")
struct RecipeEditingTests {
    private var curry: Recipe {
        get throws { try #require(try RecipeLibrary.bundled().first { $0.id == "kichererbsen-spinat-curry" }) }
    }

    @Test func blankRecipeNeedsNameAndStepText() {
        let recipe = Recipe.blank(id: "neu")
        #expect(recipe.editingProblems == [.missingName, .emptyStep("s1")])
        #expect(DeviceProfile.omniCook.validate(recipe).isEmpty)
    }

    @Test func copyGetsTheNewIdAndIsUnverified() throws {
        let copy = try curry.copy(id: "eigen-1", name: "Mein Curry")
        #expect(copy.id == "eigen-1" && copy.name == "Mein Curry" && !copy.verified)
        #expect(try copy.steps == curry.steps)
    }

    @Test func addedIngredientsGetUniqueIdsFromTheirName() throws {
        var recipe = try curry
        let first = recipe.addIngredient(named: "Zwiebel")
        let second = recipe.addIngredient(named: "")
        #expect(first == "zwiebel-2")
        #expect(second == "zutat")
        #expect(recipe.editingProblems == [.unnamedIngredient("zutat")])
    }

    @Test func removingAnIngredientRemovesItFromTheSteps() throws {
        var recipe = try curry
        recipe.removeIngredient("ingwer")
        #expect(recipe.ingredient("ingwer") == nil)
        #expect(!recipe.steps.contains { $0.ingredientIDs.contains("ingwer") })
        #expect(DeviceProfile.omniCook.validate(recipe).isEmpty)
    }

    @Test func addsStepsWithFreeIdsAtThePosition() throws {
        var recipe = try curry
        recipe.removeStep("s2")
        let added = recipe.addStep(after: 0)
        #expect(added == "s7")
        #expect(recipe.steps.map(\.id.rawValue) == ["s1", "s7", "s3", "s4", "s5", "s6"])
        #expect(recipe.stepNumber(of: "s7") == 2)
    }

    @Test(arguments: [
        (IndexSet([0]), 2, ["s2", "s1", "s3"]),
        (IndexSet([2]), 0, ["s3", "s1", "s2"]),
        (IndexSet([0, 1]), 3, ["s3", "s1", "s2"]),
        (IndexSet([1]), 1, ["s1", "s2", "s3"]),
    ])
    func movesStepsLikeAList(source: IndexSet, offset: Int, expected: [String]) {
        var recipe = Recipe.blank(id: "x")
        recipe.addStep()
        recipe.addStep()
        recipe.moveSteps(fromOffsets: source, toOffset: offset)
        #expect(recipe.steps.map(\.id.rawValue) == expected)
    }
}
