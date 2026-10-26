import Foundation
import KitchenCore

/// Plan, pantry and ticks as one JSON file in Application Support (decision 18).
actor ShoppingStore {
    static let shared = ShoppingStore()

    func load() -> ShoppingState {
        guard let data = try? Data(contentsOf: file),
            let state = try? JSONDecoder().decode(ShoppingState.self, from: data)
        else { return ShoppingState() }
        return state
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
