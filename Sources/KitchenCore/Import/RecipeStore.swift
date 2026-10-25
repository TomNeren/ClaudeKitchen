import Foundation

/// Where the cook's own recipes live. The app implements it on the file system; tests use memory.
public protocol RecipeStore: Sendable {
    func load() async throws -> [Recipe]
    func save(_ recipe: Recipe) async throws
    func delete(_ id: RecipeID) async throws
}
