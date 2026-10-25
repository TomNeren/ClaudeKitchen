import KitchenCore
import SwiftUI

/// Start screen: all recipes over the warm background, with search in the glass navigation chrome.
struct RecipeLibraryView: View {
    @State private var model = RecipeLibraryModel()
    @State private var path: [Route] = []
    @State private var isImporting = false
    @State private var isShowingSettings = false
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
                    Button("Rezept importieren", systemImage: "plus") { isImporting = true }
                }
            }
            .sheet(isPresented: $isImporting) {
                ImportRecipeView { Task { await model.loadOwn() } }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .task { await model.loadOwn() }
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
                RecipeDetailView(recipe: recipe) { servings in path.append(.cooking(id, servings: servings)) }
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
