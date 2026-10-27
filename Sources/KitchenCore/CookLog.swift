import Foundation

/// Which recipes were cooked when, with an optional rating and note per time.
public struct CookLog: Sendable, Equatable, Codable {
    public static let currentSchemaVersion = 1
    public static let ratingRange = 1...5

    public struct Entry: Sendable, Equatable, Hashable, Codable, Identifiable {
        public let id: UUID
        public var cookedAt: Date
        /// 1...5, or nil when not rated.
        public var rating: Int?
        public var note: String?

        public init(id: UUID = UUID(), cookedAt: Date, rating: Int? = nil, note: String? = nil) {
            self.id = id
            self.cookedAt = cookedAt
            self.rating = CookLog.validRating(rating)
            self.note = CookLog.cleaned(note)
        }
    }

    public var schemaVersion = CookLog.currentSchemaVersion
    /// Keyed by the raw recipe id, so the file is a plain JSON object. Entries are in recording order.
    public private(set) var entries: [String: [Entry]] = [:]

    public init() {}

    public func entries(for recipe: RecipeID) -> [Entry] {
        entries[recipe.rawValue] ?? []
    }

    public func lastCooked(for recipe: RecipeID) -> Date? {
        entries(for: recipe).map(\.cookedAt).max()
    }

    /// The rating of the most recent entry that has one.
    public func latestRating(for recipe: RecipeID) -> Int? {
        entries(for: recipe).filter { $0.rating != nil }.max { $0.cookedAt < $1.cookedAt }?.rating
    }

    /// Adds an entry and returns its id. A rating outside 1...5 is dropped, a blank note too.
    @discardableResult
    public mutating func record(
        _ recipe: RecipeID, at date: Date, rating: Int? = nil, note: String? = nil, entryID: UUID = UUID()
    ) -> UUID {
        let entry = Entry(id: entryID, cookedAt: date, rating: rating, note: note)
        entries[recipe.rawValue, default: []].append(entry)
        return entry.id
    }

    /// Sets rating and note of an existing entry. Returns false if the entry does not exist.
    @discardableResult
    public mutating func rate(entryOf recipe: RecipeID, id: UUID, rating: Int?, note: String? = nil) -> Bool {
        guard let index = entries[recipe.rawValue]?.firstIndex(where: { $0.id == id }) else { return false }
        entries[recipe.rawValue]?[index].rating = Self.validRating(rating)
        entries[recipe.rawValue]?[index].note = Self.cleaned(note)
        return true
    }

    static func validRating(_ rating: Int?) -> Int? {
        guard let rating, ratingRange.contains(rating) else { return nil }
        return rating
    }

    static func cleaned(_ note: String?) -> String? {
        guard let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
