import Foundation

/// The cuisine a recipe comes from, one of the nine the bundled collection covers (PLAN.md, decision 32).
public enum Cuisine: String, Sendable, Hashable, Codable, CaseIterable {
    case india
    case thailand
    /// Vietnam, Indonesia, Malaysia, the Philippines.
    case southeastAsia
    case china
    case japanKorea
    case turkeyLevant
    case georgia
    /// Mediterranean and Eastern Europe.
    case europe
    case mexicoPeru
}

/// Where a traditional recipe comes from.
public struct RecipeOrigin: Sendable, Hashable, Codable {
    public var cuisine: Cuisine
    /// Region or place within the cuisine, for example "Punjab" or "Ikaria".
    public var region: String?

    public init(cuisine: Cuisine, region: String? = nil) {
        self.cuisine = cuisine
        self.region = region
    }
}

/// A work the recipe draws on, cited only: no text is copied from it (PLAN.md, section 3c).
public struct RecipeReference: Sendable, Hashable, Codable {
    public var title: String
    public var author: String?
    public var year: Int?
    public var url: URL?

    public init(title: String, author: String? = nil, year: Int? = nil, url: URL? = nil) {
        self.title = title
        self.author = author
        self.year = year
        self.url = url
    }
}
