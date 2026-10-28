import Foundation
import KitchenCore
import Observation

/// The plan, the shopping list and the pantry for all screens. Every change is saved, in order.
@MainActor @Observable
final class ShoppingModel {
    private(set) var state = ShoppingState() {
        didSet {
            // Ticks do not change the list; only plan and pantry do.
            if oldValue.plan != state.plan || oldValue.pantry != state.pantry {
                refresh()
            }
        }
    }
    /// Recomputed only when the plan, the pantry or the recipes change, not on every read.
    private(set) var list = ShoppingList(items: [])
    /// The last booking (cooking or buying) and how to take it back.
    private(set) var undo: Undo?

    struct Undo {
        let label: String
        let pantry: Pantry
        /// The plan entry a cooked recipe took servings from, as it was before.
        let planEntry: MealPlan.Entry?
        /// The ticks a purchase cleared.
        let checked: Set<String>
    }

    private var recipes: [Recipe] = []
    private let store: ShoppingStore
    let catalog: FoodCatalog?
    /// Changes made before the saved state was read; they are replayed on top of it instead of overwriting it.
    private var pending: [(inout ShoppingState) -> Void] = []
    private var isLoaded = false
    private var saving: Task<Void, Never>?
    private let reminders: PlanReminders
    /// The plan the reminders were last scheduled for, so ticks and pantry changes do not reschedule them.
    private var remindedPlan: MealPlan?
    private var reminderUpdate: Task<Void, Never>?

    init(
        store: ShoppingStore = .shared, catalog: FoodCatalog? = FoodCatalog.shared,
        reminders: PlanReminders = .shared
    ) {
        self.store = store
        self.catalog = catalog
        self.reminders = reminders
    }

    func load() async {
        guard !isLoaded else { return }
        var loaded = await store.load()
        for update in pending {
            update(&loaded)
        }
        pending = []
        isLoaded = true
        state = loaded
        save()
    }

    /// The library's recipes, own and bundled, so plan entries resolve.
    func update(recipes: [Recipe]) {
        self.recipes = recipes
        refresh()
        // The reminders name the recipes, so they are scheduled again once the names are known.
        if isLoaded {
            remindedPlan = nil
            save()
        }
    }

    /// Planned recipes by day, the undated ones last.
    var planned: [PlannedRecipe] {
        state.plan.scheduled.compactMap { entry in
            recipes.first { $0.id == entry.recipe }.map { PlannedRecipe(recipe: $0, entry: entry) }
        }
    }

    func isPlanned(_ id: RecipeID) -> Bool {
        state.plan.entries.contains { $0.recipe == id }
    }

    func planEntry(for id: RecipeID) -> MealPlan.Entry? {
        state.plan.entries.first { $0.recipe == id }
    }

    /// `recipe` is the library recipe; an own recipe saved from Claude is planned as itself, not as its original.
    func add(_ recipe: Recipe, servings: Int, goal: RewriteGoalID?) {
        change { $0.plan.add(recipe.id, servings: servings, goal: goal) }
    }

    /// Asks for notifications the first time a day is set, so the morning reminder can ring.
    func setDay(_ day: PlanDay?, for id: RecipeID) {
        change { $0.plan.setDay(day, for: id) }
        guard day != nil else { return }
        let reminders = self.reminders
        Task {
            // The change above was scheduled before permission existed; once granted, schedule again.
            guard await reminders.requestAuthorization() else { return }
            remindedPlan = nil
            scheduleReminders()
        }
    }

    func setServings(_ servings: Int, for id: RecipeID) {
        change { $0.plan.setServings(servings, for: id) }
        dropStaleChecks()
    }

    func remove(_ id: RecipeID) {
        change { $0.plan.remove(id) }
        dropStaleChecks()
    }

    func isChecked(_ item: ShoppingList.Item) -> Bool {
        state.checked.contains(item.id)
    }

    func toggle(_ item: ShoppingList.Item) {
        change {
            if $0.checked.contains(item.id) {
                $0.checked.remove(item.id)
            } else {
                $0.checked.insert(item.id)
            }
        }
    }

    /// Items not ticked off yet.
    var openItems: [ShoppingList.Item] {
        list.items.filter { !state.checked.contains($0.id) }
    }

    /// The open items as a brief for a browser agent that fills the cart of the shop the cook is logged into.
    var agentBrief: String {
        AgentBrief.text(for: openItems, catalog: catalog ?? FoodCatalog(sources: [], groups: [], foods: []))
    }

    /// Writes the open items to Apple Reminders and returns the message for the cook.
    func exportToReminders() async -> String {
        do {
            return ShoppingText.exported(try await RemindersExport.shared.export(openItems.map(ShoppingText.line)))
        } catch RemindersExport.Failure.denied {
            return "Kein Zugriff auf Erinnerungen. Du kannst ihn in den Einstellungen unter Omni Cook erlauben."
        } catch RemindersExport.Failure.noWritableAccount {
            return
                "Kein Konto in Erinnerungen erlaubt eine neue Liste. Lege eine Liste „\(RemindersExport.listTitle)“ an, dann füllt die App sie."
        } catch {
            return "Die Liste ließ sich nicht in Erinnerungen anlegen."
        }
    }

    var hasChecked: Bool {
        list.items.contains { state.checked.contains($0.id) }
    }

    func buyChecked() {
        let list = list
        undo = Undo(label: "Einkauf eingebucht", pantry: state.pantry, planEntry: nil, checked: state.checked)
        change { $0.buyChecked(from: list) }
    }

    /// Called when the cook finishes a recipe in the cooking mode. `recipe` is what was cooked (maybe a health
    /// variant), `planned` the library recipe it started from.
    func cooked(_ recipe: Recipe, as planned: RecipeID, servings: Int) {
        guard let catalog else { return }
        let entry = state.plan.entries.first { $0.recipe == planned }
        undo = Undo(label: "\(recipe.name) abgebucht", pantry: state.pantry, planEntry: entry, checked: [])
        change { $0.cooked(recipe, as: planned, servings: servings, catalog: catalog) }
        dropStaleChecks()
    }

    /// Takes back only what the last booking changed: the pantry, the cooked plan entry and cleared ticks. Plan and
    /// tick changes made since stay.
    func undoLastBooking() {
        guard let undo else { return }
        change { state in
            state.pantry = undo.pantry
            if let entry = undo.planEntry {
                state.plan.restore(entry)
            }
            state.checked.formUnion(undo.checked)
        }
        self.undo = nil
    }

    func setPantryItem(_ item: PantryItem?, for food: FoodID) {
        change { $0.pantry[food] = item }
    }

    var pantryItems: [PantryEntry] {
        state.pantry.items.map { PantryEntry(item: $0, name: catalog?.food($0.food)?.name ?? $0.food.rawValue) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Catalog foods that are not in the pantry yet, to add one.
    var addableFoods: [Food] {
        (catalog?.foods ?? []).filter { $0.id != Food.water && state.pantry[$0.id] == nil }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// A new pantry entry for `food`: by level for seasonings, else in grams.
    func newPantryItem(for food: Food) -> PantryItem {
        let byLevel = catalog?.tracksLevel(food) ?? false
        return PantryItem(food: food.id, stock: byLevel ? .level(.available) : .grams(0))
    }

    private func change(_ update: @escaping (inout ShoppingState) -> Void) {
        var state = state
        update(&state)
        self.state = state
        if isLoaded {
            save()
        } else {
            pending.append(update)
        }
    }

    /// Saves one after the other, so an older state never lands on disk after a newer one. Reschedules the morning
    /// reminders when the plan changed; only after loading, so an empty plan never clears them.
    private func save() {
        if remindedPlan != state.plan {
            remindedPlan = state.plan
            scheduleReminders()
        }
        let snapshot = state
        let previous = saving
        saving = Task { [store] in
            await previous?.value
            await store.save(snapshot)
        }
    }

    private func scheduleReminders() {
        // Without the library the reminders would have no names; `update(recipes:)` schedules them again.
        guard !recipes.isEmpty else {
            remindedPlan = nil
            return
        }
        let names = Dictionary(recipes.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let today = PlanDay(.now, calendar: .current)
        let days = state.plan.reminders(from: today).map { reminder in
            PlanReminders.Day(
                day: reminder.day,
                lines: reminder.entries.compactMap { entry in
                    names[entry.recipe].map { "\($0) (\(Portions.text(entry.servings)))" }
                })
        }
        let previous = reminderUpdate
        let reminders = self.reminders
        reminderUpdate = Task {
            await previous?.value
            await reminders.schedule(days.filter { !$0.lines.isEmpty })
        }
    }

    /// Only once recipes are known; before that the list is empty and every tick would look stale.
    private func dropStaleChecks() {
        guard !recipes.isEmpty else { return }
        let list = list
        change { $0.keepChecks(on: list) }
    }

    private func refresh() {
        guard let catalog else { return }
        list = state.list(recipes: recipes, catalog: catalog) { recipe, goal in
            HealthGoals.variantRecipe(of: recipe, for: goal)
        }
    }
}

struct PlannedRecipe: Identifiable {
    let recipe: Recipe
    let entry: MealPlan.Entry

    var id: RecipeID { recipe.id }
}

struct PantryEntry: Identifiable {
    let item: PantryItem
    let name: String

    var id: FoodID { item.food }
}
