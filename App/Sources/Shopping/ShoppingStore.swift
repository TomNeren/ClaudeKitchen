import Foundation
import KitchenCore

/// Plan, pantry and ticks as one JSON file in Application Support (decision 18).
actor ShoppingStore {
    static let shared = ShoppingStore()

    /// An unreadable or newer file is moved aside instead of being overwritten by the next save, so a pantry is
    /// never lost to a decoding problem.
    func load() -> ShoppingState {
        guard let data = try? Data(contentsOf: file) else { return ShoppingState() }
        if let state = try? JSONDecoder().decode(ShoppingState.self, from: data),
            state.schemaVersion <= ShoppingState.currentSchemaVersion
        {
            return state
        }
        let aside = file.deletingLastPathComponent()
            .appending(path: "shopping-unreadable-\(Int(Date.now.timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: file, to: aside)
        return ShoppingState()
    }

    func save(_ state: ShoppingState) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? encoder.encode(state).write(to: file, options: .atomic)
    }

    private var file: URL {
        let directory =
            (try? FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return directory.appending(path: "shopping.json")
    }
}
