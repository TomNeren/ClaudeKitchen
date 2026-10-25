import Foundation

/// Loads the recipes that ship with the app.
public enum RecipeLibrary {
    public enum LoadError: Error, Equatable {
        case missingResources
        case unsupportedSchemaVersion(file: String, version: Int)
    }

    /// All bundled recipes, sorted by name.
    public static func bundled() throws -> [Recipe] {
        guard let directory = Bundle.module.url(forResource: "Recipes", withExtension: nil) else {
            throw LoadError.missingResources
        }
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        guard !urls.isEmpty else { throw LoadError.missingResources }
        return try urls.map(load).sorted { $0.name < $1.name }
    }

    public static func load(from url: URL) throws -> Recipe {
        let recipe = try decode(Data(contentsOf: url))
        guard recipe.schemaVersion <= Recipe.currentSchemaVersion else {
            throw LoadError.unsupportedSchemaVersion(file: url.lastPathComponent, version: recipe.schemaVersion)
        }
        return recipe
    }

    public static func decode(_ data: Data) throws -> Recipe {
        try JSONDecoder().decode(Recipe.self, from: data)
    }
}

extension Recipe {
    /// Bundled recipes for SwiftUI previews. Empty if the resources cannot be read; tests use `bundled()` instead.
    public static let fixtures: [Recipe] = (try? RecipeLibrary.bundled()) ?? []
}
