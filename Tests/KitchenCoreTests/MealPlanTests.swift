import Foundation
import Testing

@testable import KitchenCore

@Suite("Meal plan and shopping state")
struct MealPlanTests {
    private static let catalog = FoodCatalog(
        sources: [], groups: [FoodGroup(id: "dry", name: "Trocken", direction: .notAssessed, aisle: .dryGoods)],
        foods: [Food(id: "lentils", name: "Rote Linsen", group: "dry", role: .base)])

    private static let dal = Recipe(
        id: "dal", name: "Dal", tag: "", baseServings: 2, totalMinutes: 10,
        ingredients: [Ingredient(id: "l", name: "Linsen", amount: .measured(200, .gram), food: "lentils")],
        steps: [])

    @Test func addingAgainAddsServingsAndServingsStayPositive() {
        var plan = MealPlan()
        plan.add("dal", servings: 2)
        plan.add("dal", servings: 0)
        plan.add("soup", servings: 4)
        #expect(plan.entries == [.init(recipe: "dal", servings: 3), .init(recipe: "soup", servings: 4)])
        plan.setServings(-2, for: "soup")
        plan.setServings(5, for: "unknown")
        plan.remove("dal")
        #expect(plan.entries == [.init(recipe: "soup", servings: 1)])
    }

    @Test func plansSkipRecipesThatAreGone() {
        let plan = MealPlan(entries: [.init(recipe: "gone", servings: 2), .init(recipe: "dal", servings: 4)])
        let plans = plan.plans(in: [Self.dal])
        #expect(plans.map(\.recipe.id) == ["dal"])
        #expect(plans.map(\.servings) == [4])
    }

    @Test func buyingTheCheckedItemsEmptiesTheListButKeepsThePlan() {
        var state = ShoppingState(plan: MealPlan(entries: [.init(recipe: "dal", servings: 2)]))
        let list = state.list(recipes: [Self.dal], catalog: Self.catalog)
        #expect(list.items.map(\.id) == ["food:lentils"])
        state.checked = ["food:lentils", "name:Alt"]
        state.buyChecked(from: list)
        #expect(state.checked.isEmpty)
        #expect(state.pantry["lentils"]?.stock == .grams(200))
        #expect(state.list(recipes: [Self.dal], catalog: Self.catalog).items.isEmpty)
        #expect(state.plan.entries.count == 1)
    }

    @Test func uncheckedItemsAreNotBooked() {
        var state = ShoppingState(plan: MealPlan(entries: [.init(recipe: "dal", servings: 2)]))
        state.buyChecked(from: state.list(recipes: [Self.dal], catalog: Self.catalog))
        #expect(state.pantry.items.isEmpty)
    }

    @Test func cookingAVariantDeductsAndDropsTheOriginalFromThePlan() {
        var state = ShoppingState(
            plan: MealPlan(entries: [.init(recipe: "dal", servings: 2)]),
            pantry: Pantry(items: [PantryItem(food: "lentils", stock: .grams(500))]))
        var variant = Self.dal
        variant.variantOf = "dal"
        state.cooked(variant, servings: 2, catalog: Self.catalog)
        #expect(state.pantry["lentils"]?.stock == .grams(300))
        #expect(state.plan.entries.isEmpty)
    }

    @Test func stateRoundTripsThroughJSON() throws {
        let state = ShoppingState(
            plan: MealPlan(entries: [.init(recipe: "dal", servings: 2)]),
            pantry: Pantry(items: [PantryItem(food: "salt", stock: .level(.low))]), checked: ["food:salt"])
        #expect(try JSONDecoder().decode(ShoppingState.self, from: JSONEncoder().encode(state)) == state)
    }

    @Test func itemIDsAreStableAndDistinguishUnknownNames() {
        let known = ShoppingList.Item(
            food: "lentils", name: "Rote Linsen", aisle: .dryGoods, quantity: .level, reason: .needed, recipes: [])
        let unknown = ShoppingList.Item(
            food: nil, name: "Drachenfrucht", aisle: .other, quantity: .unknown, reason: .needed, recipes: [])
        #expect(known.id == "food:lentils")
        #expect(unknown.id == "name:Drachenfrucht")
        #expect(ShoppingList(items: [known, unknown]).filtered(to: ["name:Drachenfrucht"]).items == [unknown])
    }
}
