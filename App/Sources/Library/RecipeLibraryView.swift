import KitchenCore
import SwiftUI

/// Start screen: all recipes over the warm background, with search in the glass navigation chrome.
struct RecipeLibraryView: View {
    @State private var model = RecipeLibraryModel()
    @State private var path: [Route] = []
    @State private var isImporting = false
    @State private var isShowingSettings = false
    @State private var editing: EditorRequest?
    @State private var saveFailed = false
    @Namespace private var transition

    init() {}

    var body: some View {
        NavigationStack(path: $path) {
            let recipes = model.visibleRecipes
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
                    ForEach(recipes) { recipe in
                        NavigationLink(value: Route.recipe(recipe.id)) {
                            RecipeCard(recipe: recipe)
                                .matchedTransitionSource(id: recipe.id, in: transition)
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
            .sheet(item: $editing) { request in
                RecipeEditorView(recipe: request.recipe, isNew: request.isNew) { recipe in
                    await save(recipe, copiedFrom: request.copiedFrom)
                }
            }
            .alert("Speichern fehlgeschlagen", isPresented: $saveFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Das Rezept konnte nicht gesichert werden. Ist genug Speicher frei?")
            }
            .task { await model.loadOwn() }
        }
    }

    private func save(_ recipe: Recipe, copiedFrom original: RecipeID?) async {
        guard await model.save(recipe) else {
            saveFailed = true
            return
        }
        // Edited a bundled recipe from its screen: show the own copy instead.
        if let original, let last = path.last, last == .recipe(original) {
            path[path.count - 1] = .recipe(recipe.id)
        }
    }

    @ViewBuilder
    private func emptyState(isEmpty: Bool) -> some View {
        if model.loadFailed {
            ContentUnavailableView(
                "Rezepte nicht lesbar", systemImage: "exclamationmark.triangle",
                description: Text("Die mitgelieferten Rezepte konnten nicht geladen werden."))
        } else if isEmpty {
            ContentUnavailableView.search(text: model.query)
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .recipe(let id):
            if let recipe = model.recipe(id) {
                RecipeDetailView(
                    recipe: recipe, isOwn: model.isOwn(id),
                    onEdit: { editing = model.editorRequest(for: id) }
                ) { servings in path.append(.cooking(id, servings: servings)) }
                // A saved change gives the screen a fresh model.
                .id(recipe)
                .navigationTransition(.zoom(sourceID: id, in: transition))
            }
        case .cooking(let id, let servings):
            if let recipe = model.recipe(id) {
                CookingView(recipe: recipe, servings: servings) { path.removeAll() }
            }
        }
    }
}

#Preview {
    RecipeLibraryView()
}
