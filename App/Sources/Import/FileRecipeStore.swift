import Foundation
import KitchenCore

/// Own recipes as JSON files in Application Support, one file per recipe, in the same format as the bundled ones.
actor FileRecipeStore: RecipeStore {
    static let shared = FileRecipeStore()

    private var directory: URL {
        get throws {
            let url = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            ).appending(path: "Recipes", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
    }

    func load() throws -> [Recipe] {
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        // A damaged file must not hide the others. Recipes saved before foods were assigned by name get them here.
        let recipes = urls.compactMap { try? RecipeLibrary.load(from: $0) }.sorted { $0.name < $1.name }
        guard let catalog = FoodCatalog.shared else { return recipes }
        return recipes.map { $0.assigningFoods(from: catalog) }
    }

    func save(_ recipe: Recipe) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(recipe).write(to: try file(for: recipe.id), options: .atomic)
    }

    func delete(_ id: RecipeID) throws {
        try FileManager.default.removeItem(at: try file(for: id))
    }

    private func file(for id: RecipeID) throws -> URL {
        try directory.appending(path: "\(id.rawValue).json")
    }
}
