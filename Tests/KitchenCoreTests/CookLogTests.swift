import Foundation
import Testing

@testable import KitchenCore

@Suite("CookLog")
struct CookLogTests {
    private let recipe: RecipeID = "dal"
    private let early = Date(timeIntervalSince1970: 1_000_000)
    private let late = Date(timeIntervalSince1970: 2_000_000)

    @Test func recordsAndFindsLastDate() {
        var log = CookLog()
        #expect(log.lastCooked(for: recipe) == nil)
        log.record(recipe, at: late)
        log.record(recipe, at: early)
        #expect(log.lastCooked(for: recipe) == late)
        #expect(log.entries(for: recipe).count == 2)
        #expect(log.lastCooked(for: "other") == nil)
    }

    @Test func dropsInvalidRatingAndBlankNote() {
        var log = CookLog()
        log.record(recipe, at: early, rating: 0, note: "  ")
        log.record(recipe, at: late, rating: 6)
        #expect(log.entries(for: recipe).allSatisfy { $0.rating == nil && $0.note == nil })
        log.record(recipe, at: late, rating: 5, note: " mehr Salz ")
        #expect(log.latestRating(for: recipe) == 5)
        #expect(log.entries(for: recipe).last?.note == "mehr Salz")
    }

    @Test func rateUpdatesEntry() {
        var log = CookLog()
        let id = log.record(recipe, at: early)
        #expect(log.latestRating(for: recipe) == nil)
        let updated = log.rate(entryOf: recipe, id: id, rating: 4, note: "gut")
        let unknownEntry = log.rate(entryOf: recipe, id: UUID(), rating: 3)
        let unknownRecipe = log.rate(entryOf: "other", id: id, rating: 3)
        #expect(updated)
        #expect(!unknownEntry)
        #expect(!unknownRecipe)
        #expect(log.latestRating(for: recipe) == 4)
    }

    @Test func latestRatingUsesNewestRatedEntry() {
        var log = CookLog()
        log.record(recipe, at: early, rating: 2)
        log.record(recipe, at: late, rating: nil)
        #expect(log.latestRating(for: recipe) == 2)
        log.record(recipe, at: late.addingTimeInterval(1), rating: 5)
        #expect(log.latestRating(for: recipe) == 5)
    }

    @Test func jsonRoundTrip() throws {
        var log = CookLog()
        log.record(recipe, at: early, rating: 3, note: "x")
        let data = try JSONEncoder().encode(log)
        let decoded = try JSONDecoder().decode(CookLog.self, from: data)
        #expect(decoded == log)
    }
}
