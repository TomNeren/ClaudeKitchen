import Foundation

/// Short explanations of spices, blends and seasonings outside everyday German cooking: what Garam Masala is made
/// of, what Doubanjiang tastes like, what to use instead.
///
/// Ships as `Resources/Guide/spice-guide.json`, keyed by catalog food, so every recipe ingredient that points at one
/// of these foods finds its entry.
public struct SpiceGuide: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public enum LoadError: Error, Equatable {
        case missingResource
        case unsupportedSchemaVersion(Int)
    }

    public struct Entry: Sendable, Hashable, Codable, Identifiable {
        public enum Kind: String, Sendable, Hashable, Codable, CaseIterable {
            case blend, spice, herb, paste, liquid, other
        }

        public let food: FoodID
        public var kind: Kind
        /// What it is and where it comes from.
        public var summary: String
        /// What a blend is made of, most important first; empty for single spices.
        public var components: [String]
        public var taste: String
        /// How to handle it in the pot.
        public var tip: String?
        /// What to use when it is not at home.
        public var substitute: String?

        public var id: FoodID { food }

        public init(
            food: FoodID, kind: Kind, summary: String, components: [String] = [], taste: String, tip: String? = nil,
            substitute: String? = nil
        ) {
            self.food = food
            self.kind = kind
            self.summary = summary
            self.components = components
            self.taste = taste
            self.tip = tip
            self.substitute = substitute
        }

        private enum CodingKeys: String, CodingKey {
            case food, kind, summary, components, taste, tip, substitute
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            food = try container.decode(FoodID.self, forKey: .food)
            kind = try container.decode(Kind.self, forKey: .kind)
            summary = try container.decode(String.self, forKey: .summary)
            components = try container.decodeIfPresent([String].self, forKey: .components) ?? []
            taste = try container.decode(String.self, forKey: .taste)
            tip = try container.decodeIfPresent(String.self, forKey: .tip)
            substitute = try container.decodeIfPresent(String.self, forKey: .substitute)
        }
    }

    public var schemaVersion: Int
    public var entries: [Entry]

    public init(entries: [Entry], schemaVersion: Int = SpiceGuide.currentSchemaVersion) {
        self.schemaVersion = schemaVersion
        self.entries = entries
    }

    /// The bundled guide, loaded once; nil if it cannot be read.
    public static let shared: SpiceGuide? = try? bundled()

    public static func bundled() throws -> SpiceGuide {
        guard let url = Bundle.module.url(forResource: "spice-guide", withExtension: "json", subdirectory: "Guide")
        else {
            throw LoadError.missingResource
        }
        return try decode(Data(contentsOf: url))
    }

    /// Checks the schema version before the rest, so a newer file fails with `unsupportedSchemaVersion`.
    public static func decode(_ data: Data) throws -> SpiceGuide {
        struct Header: Decodable { var schemaVersion: Int }
        let version = try JSONDecoder().decode(Header.self, from: data).schemaVersion
        guard version <= currentSchemaVersion else {
            throw LoadError.unsupportedSchemaVersion(version)
        }
        return try JSONDecoder().decode(SpiceGuide.self, from: data)
    }

    public func entry(for food: FoodID?) -> Entry? {
        guard let food else { return nil }
        return entries.first { $0.food == food }
    }

    /// The entries `recipe` needs, in ingredient order, each once ("Ghee" twice in a recipe is one entry).
    public func entries(for recipe: Recipe) -> [(ingredient: Ingredient, entry: Entry)] {
        var seen: Set<FoodID> = []
        return recipe.ingredients.compactMap { ingredient in
            guard let entry = entry(for: ingredient.food), seen.insert(entry.food).inserted else { return nil }
            return (ingredient, entry)
        }
    }
}

extension SpiceGuide {
    /// The entry a spoken or typed name means, with the name to say: an ingredient of `recipe` first ("Masala" finds
    /// "Garam Masala" there), else any catalog food by name or alias ("Hing" finds Asafoetida). Nil when the guide
    /// has nothing on it.
    public func entry(named name: String, in session: CookingSession?, catalog: FoodCatalog?) -> (
        name: String, entry: Entry
    )? {
        if let ingredient = session?.ingredient(named: name), let entry = entry(for: ingredient.food) {
            return (ingredient.name, entry)
        }
        guard let catalog, let food = catalog.food(named: name), let entry = entry(for: food) else { return nil }
        return (catalog.food(food)?.name ?? name, entry)
    }
}
