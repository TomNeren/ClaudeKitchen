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

    @Test func cookingTakesServingsOffThePlanAndKeepsTheRest() {
        var plan = MealPlan(entries: [.init(recipe: "dal", servings: 6, goal: "balanced")])
        plan.cooked("dal", servings: 2)
        #expect(plan.entries == [.init(recipe: "dal", servings: 4, goal: "balanced")])
        plan.cooked("soup", servings: 2)
        plan.cooked("dal", servings: 10)
        #expect(plan.entries.isEmpty)
    }

    @Test func plansUseTheVariantOfTheirGoal() {
        var plan = MealPlan()
        plan.add("dal", servings: 2, goal: "low-carb")
        var variant = Self.dal
        variant.name = "Dal Low Carb"
        let plans = plan.plans(in: [Self.dal]) { recipe, goal in goal == "low-carb" ? variant : nil }
        #expect(plans.map(\.recipe.name) == ["Dal Low Carb"])
        plan.add("dal", servings: 1)
        #expect(plan.entries == [.init(recipe: "dal", servings: 3)])
    }

    @Test func ticksOfItemsThatLeftTheListAreDropped() {
        var state = ShoppingState(checked: ["food:lentils", "food:rice"])
        let list = ShoppingList(items: [
            .init(food: "rice", name: "Reis", aisle: .dryGoods, quantity: .level, reason: .needed, recipes: [])
        ])
        state.keepChecks(on: list)
        #expect(state.checked == ["food:rice"])
    }

    @Test func cookingAVariantDeductsAndDropsTheOriginalFromThePlan() {
        var state = ShoppingState(
            plan: MealPlan(entries: [.init(recipe: "dal", servings: 2)]),
            pantry: Pantry(items: [PantryItem(food: "lentils", stock: .grams(500))]))
        var variant = Self.dal
        variant.variantOf = "dal"
        state.cooked(variant, as: "dal", servings: 2, catalog: Self.catalog)
        #expect(state.pantry["lentils"]?.stock == .grams(300))
        #expect(state.plan.entries.isEmpty)
    }

    /// An own recipe from "Mit Claude verbessern" names its original in `variantOf` but is planned on its own.
    @Test func cookingAnOwnImprovedRecipeLeavesTheOriginalPlanned() {
        var state = ShoppingState(
            plan: MealPlan(entries: [.init(recipe: "dal", servings: 2), .init(recipe: "dal-besser", servings: 3)]))
        var improved = Recipe(
            id: "dal-besser", name: "Dal, verbessert", tag: "", baseServings: 2, totalMinutes: 10,
            ingredients: Self.dal.ingredients, steps: [])
        improved.variantOf = "dal"
        state.cooked(improved, as: improved.id, servings: 3, catalog: Self.catalog)
        #expect(state.plan.entries == [.init(recipe: "dal", servings: 2)])
    }

    @Test func daysSortThePlanAndSurviveAddingAgain() {
        let monday = PlanDay(year: 2026, month: 11, day: 2)
        var plan = MealPlan()
        plan.add("soup", servings: 2)
        plan.add("dal", servings: 2)
        plan.add("curry", servings: 2)
        plan.setDay(monday.adding(days: 2, calendar: Self.calendar), for: "soup")
        plan.setDay(monday, for: "curry")
        plan.add("soup", servings: 1)
        #expect(plan.scheduled.map(\.recipe) == ["curry", "soup", "dal"])
        #expect(plan.entries.first { $0.recipe == "soup" }?.day == PlanDay(year: 2026, month: 11, day: 4))
        plan.setDay(nil, for: "curry")
        #expect(plan.scheduled.map(\.recipe) == ["soup", "dal", "curry"])
    }

    @Test func remindersGroupByDayAndSkipThePast() {
        let today = PlanDay(year: 2026, month: 10, day: 28)
        let plan = MealPlan(entries: [
            .init(recipe: "old", servings: 2, day: PlanDay(year: 2026, month: 10, day: 27)),
            .init(recipe: "dal", servings: 2, day: today),
            .init(recipe: "rice", servings: 2, day: today),
            .init(recipe: "soup", servings: 2, day: PlanDay(year: 2026, month: 11, day: 1)),
            .init(recipe: "someday", servings: 2),
        ])
        let reminders = plan.reminders(from: today)
        #expect(reminders.map(\.day) == [today, PlanDay(year: 2026, month: 11, day: 1)])
        #expect(reminders.first?.entries.map(\.recipe) == ["dal", "rice"])
    }

    @Test func restoreBringsBackTheDay() {
        let day = PlanDay(year: 2026, month: 10, day: 30)
        var plan = MealPlan(entries: [.init(recipe: "dal", servings: 2, day: day)])
        let before = plan.entries[0]
        plan.cooked("dal", servings: 2)
        plan.restore(before)
        #expect(plan.entries == [before])
    }

    @Test func plansWithoutDaysStillDecode() throws {
        let json = #"{"entries": [{"recipe": "dal", "servings": 2}]}"#
        let plan = try JSONDecoder().decode(MealPlan.self, from: Data(json.utf8))
        #expect(plan.entries == [.init(recipe: "dal", servings: 2)])
    }

    @Test(arguments: [
        (PlanDay(year: 2026, month: 10, day: 31), 1, PlanDay(year: 2026, month: 11, day: 1)),
        (PlanDay(year: 2026, month: 12, day: 30), 3, PlanDay(year: 2027, month: 1, day: 2)),
        (PlanDay(year: 2028, month: 3, day: 1), -1, PlanDay(year: 2028, month: 2, day: 29)),
    ])
    func daysAddAcrossMonthAndYear(start: PlanDay, count: Int, expected: PlanDay) {
        #expect(start.adding(days: count, calendar: Self.calendar) == expected)
    }

    @Test func dayOfADateFollowsTheCalendarsTimeZone() throws {
        var berlin = Calendar(identifier: .gregorian)
        berlin.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        // 23:30 UTC on 27 October is already 28 October in Berlin.
        let date = try #require(ISO8601DateFormatter().date(from: "2026-10-27T23:30:00Z"))
        #expect(PlanDay(date, calendar: berlin) == PlanDay(year: 2026, month: 10, day: 28))
        #expect(
            PlanDay(year: 2026, month: 10, day: 28).following(3, calendar: berlin).last?.description == "2026-10-30")
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

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
