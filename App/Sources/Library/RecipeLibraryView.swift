import KitchenCore
import SwiftUI

/// Start screen: all recipes over the warm background, with search in the glass navigation chrome.
struct RecipeLibraryView: View {
    @State private var model = RecipeLibraryModel()
    @State private var shopping = ShoppingModel()
    @State private var cookLog = CookLogModel()
    @State private var rating: RatingRequest?
    @State private var isShopping = false
    @State private var path: [Route] = []
    @State private var isImporting = false
    @State private var isShowingSettings = false
    @State private var editing: EditorRequest?
    @Namespace private var transition
    /// The tile or card the open recipe zooms out of.
    @State private var zoomSource: ZoomSource?

    init() {}

    var body: some View {
        NavigationStack(path: $path) {
            let recipes = model.visibleRecipes
            ScrollView {
                if model.query.isEmpty, !recipes.isEmpty {
                    RecipeImageBand(recipes: recipes, cookLog: cookLog.log, transition: transition, onOpen: open)
                        .padding(.bottom, 16)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
                    ForEach(recipes) { recipe in
                        Button {
                            open(.card(recipe.id))
                        } label: {
                            RecipeCard(recipe: recipe, cookLog: cookLog.log)
                                .matchedTransitionSource(id: ZoomSource.card(recipe.id), in: transition)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(
                                model.isOwn(recipe.id) ? "Bearbeiten" : "Als eigenes Rezept bearbeiten",
                                systemImage: "pencil"
                            ) {
                                editing = model.editorRequest(for: recipe.id)
                            }
                            if model.isOwn(recipe.id) {
                                Button("Löschen", systemImage: "trash", role: .destructive) {
                                    Task { await model.delete(recipe.id) }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .animation(Motion.searchResults, value: recipes.map(\.id))
            }
            .background { WarmBackground() }
            .overlay { emptyState(isEmpty: recipes.isEmpty) }
            .navigationTitle("Omni Cook")
            .searchable(text: $model.query, prompt: "Gericht oder Zutat")
            .navigationDestination(for: Route.self) { route in
                destination(for: route)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Einstellungen", systemImage: "gearshape") { isShowingSettings = true }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Einkauf", systemImage: "cart") { isShopping = true }
                }
                if !model.cuisines.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        CuisineFilter(model: model)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Rezept hinzufügen", systemImage: "plus") {
                        Button("Neues Rezept", systemImage: "square.and.pencil") {
                            editing = model.newRecipeRequest()
                        }
                        Button("Rezept importieren", systemImage: "square.and.arrow.down") { isImporting = true }
                    }
                }
            }
            .sheet(isPresented: $isImporting) {
                ImportRecipeView { Task { await model.loadOwn() } }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $isShopping) {
                ShoppingView(model: shopping)
            }
            .sheet(item: $editing) { request in
                RecipeEditorView(recipe: request.recipe, isNew: request.isNew) { recipe in
                    await save(recipe, copiedFrom: request.copiedFrom)
                }
            }
            .sheet(item: $rating) { request in
                CookRatingSheet(recipeName: request.name) { stars, note in
                    cookLog.rate(request.recipe, entry: request.entry, rating: stars, note: note)
                }
            }
            .task {
                await cookLog.load()
                await model.loadOwn()
                await shopping.load()
                shopping.update(recipes: model.recipes)
            }
            .onChange(of: model.recipes) { shopping.update(recipes: model.recipes) }
        }
    }

    private func save(_ recipe: Recipe, copiedFrom original: RecipeID?) async -> Bool {
        guard await model.save(recipe) else { return false }
        // Edited a bundled recipe from its screen: show the own copy instead.
        if let original, let last = path.last, last == .recipe(original) {
            path[path.count - 1] = .recipe(recipe.id)
        }
        return true
    }

    @ViewBuilder
    private func emptyState(isEmpty: Bool) -> some View {
        if model.loadFailed {
            ContentUnavailableView(
                "Rezepte nicht lesbar", systemImage: "exclamationmark.triangle",
                description: Text("Die mitgelieferten Rezepte konnten nicht geladen werden."))
        } else if isEmpty, let cuisine = model.cuisine {
            ContentUnavailableView {
                Label("Nichts aus \(cuisine.displayName)", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text(
                    model.query.isEmpty
                        ? "Für diese Küche gibt es noch kein Rezept." : "Keine Treffer für „\(model.query)“.")
            } actions: {
                Button("Filter zurücksetzen") { model.cuisine = nil }
            }
        } else if isEmpty {
            ContentUnavailableView.search(text: model.query)
        }
    }

    private func open(_ source: ZoomSource) {
        zoomSource = source
        path.append(.recipe(source.recipeID))
    }

    /// The tapped tile or card; recipes opened from inside another recipe zoom from their list card.
    private func zoomSource(for id: RecipeID) -> ZoomSource {
        if let zoomSource, zoomSource.recipeID == id { return zoomSource }
        return .card(id)
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .recipe(let id):
            if let recipe = model.recipe(id) {
                RecipeDetailView(
                    recipe: recipe, isOwn: model.isOwn(id),
                    onEdit: { editing = model.editorRequest(for: id) },
                    isPlanned: shopping.isPlanned(id),
                    onAddToShopping: { shopping.add(recipe, servings: $0, goal: $1) }
                ) { servings, goal in path.append(.cooking(id, servings: servings, goal: goal)) }
                // A saved change gives the screen a fresh model.
                .id(recipe)
                .navigationTransition(.zoom(sourceID: zoomSource(for: id), in: transition))
            }
        case .cooking(let id, let servings, let goal):
            if let recipe = model.recipe(id) {
                let variant = goal.flatMap { HealthGoals.variantRecipe(of: recipe, for: $0) }
                let cooked = variant ?? recipe
                CookingView(recipe: cooked, servings: servings) {
                    // Books what the recipe used out of the pantry; the shopping screen offers undo.
                    shopping.cooked(cooked, servings: servings)
                    // The log keeps the original recipe id, so a health variant counts for its source.
                    let entry = cookLog.recordCooked(recipe.id)
                    rating = RatingRequest(recipe: recipe.id, name: recipe.name, entry: entry)
                    path.removeAll()
                }
            }
        }
    }
}

/// Which finished cooking session the rating sheet is about.
private struct RatingRequest: Identifiable {
    let recipe: RecipeID
    let name: String
    let entry: UUID
    var id: UUID { entry }
}

/// Toolbar menu that narrows the library to one cuisine. The filled icon shows that a filter is active.
private struct CuisineFilter: View {
    @Bindable var model: RecipeLibraryModel

    var body: some View {
        Menu {
            Picker("Küche", selection: $model.cuisine) {
                Text("Alle Küchen").tag(Cuisine?.none)
                ForEach(model.cuisines, id: \.self) { cuisine in
                    Text(cuisine.displayName).tag(Optional(cuisine))
                }
            }
        } label: {
            Label(
                "Küche",
                systemImage: model.cuisine == nil
                    ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityValue(model.cuisine?.displayName ?? "Alle Küchen")
    }
}

#Preview {
    RecipeLibraryView()
}
