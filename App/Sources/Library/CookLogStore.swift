import Foundation
import KitchenCore

/// Cook log as one JSON file in Application Support.
actor CookLogStore {
    static let shared = CookLogStore()

    /// An unreadable or newer file is moved aside instead of being overwritten by the next save, so a log is
    /// never lost to a decoding problem.
    func load() -> CookLog {
        guard let data = try? Data(contentsOf: file) else { return CookLog() }
        if let state = try? JSONDecoder().decode(CookLog.self, from: data),
            state.schemaVersion <= CookLog.currentSchemaVersion
        {
            return state
        }
        let aside = file.deletingLastPathComponent()
            .appending(path: "cooklog-unreadable-\(Int(Date.now.timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: file, to: aside)
        return CookLog()
    }

    func save(_ state: CookLog) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? encoder.encode(state).write(to: file, options: .atomic)
    }

    private var file: URL {
        let directory =
            (try? FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return directory.appending(path: "cooklog.json")
    }
}
