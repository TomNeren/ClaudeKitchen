import Foundation
import KitchenCore
import Observation

/// The cook log for all screens. Every change is saved, in order.
@MainActor @Observable
final class CookLogModel {
    private(set) var log = CookLog()
    private let store: CookLogStore
    private var isLoaded = false
    private var saving: Task<Void, Never>?
    /// Changes made before the saved log was read; replayed on top of it.
    private var pending: [(inout CookLog) -> Void] = []

    init(store: CookLogStore = .shared) {
        self.store = store
    }

    func load() async {
        guard !isLoaded else { return }
        var loaded = await store.load()
        for update in pending { update(&loaded) }
        pending = []
        isLoaded = true
        log = loaded
        if !loaded.entries.isEmpty { save() }
    }

    func lastCooked(_ id: RecipeID) -> Date? { log.lastCooked(for: id) }
    func latestRating(_ id: RecipeID) -> Int? { log.latestRating(for: id) }

    /// Records a finished session and returns the entry id so a rating can follow.
    @discardableResult
    func recordCooked(_ id: RecipeID, at date: Date = .now) -> UUID {
        let entryID = UUID()
        apply { _ = $0.record(id, at: date, entryID: entryID) }
        return entryID
    }

    func rate(_ id: RecipeID, entry: UUID, rating: Int?, note: String?) {
        apply { _ = $0.rate(entryOf: id, id: entry, rating: rating, note: note) }
    }

    private func apply(_ update: @escaping (inout CookLog) -> Void) {
        update(&log)
        if isLoaded {
            save()
        } else {
            pending.append(update)
        }
    }

    private func save() {
        let snapshot = log
        let previous = saving
        saving = Task {
            await previous?.value
            await store.save(snapshot)
        }
    }
}
