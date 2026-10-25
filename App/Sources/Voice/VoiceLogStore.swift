import Foundation
import KitchenCore

/// The voice log as one JSON file in Application Support. Stays on this device until the cook shares or clears it.
actor VoiceLogStore {
    static let shared = VoiceLogStore()

    /// The settings key for recording; on unless switched off.
    static let enabledKey = "voiceLogOn"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    private var log: VoiceLog?

    func entries() -> [VoiceLog.Entry] {
        loaded().entries
    }

    func exportText() -> String {
        loaded().exportText()
    }

    func append(_ entry: VoiceLog.Entry) {
        var log = loaded()
        log.append(entry)
        save(log)
    }

    func setLastReply(_ reply: String) {
        var log = loaded()
        log.setLastReply(reply)
        save(log)
    }

    func clear() {
        save(VoiceLog())
    }

    private func loaded() -> VoiceLog {
        if let log { return log }
        let loaded = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(VoiceLog.self, from: $0) }
        let log = loaded ?? VoiceLog()
        self.log = log
        return log
    }

    private func save(_ log: VoiceLog) {
        self.log = log
        // Losing a log line is harmless; the cook must never notice a failed write.
        try? JSONEncoder().encode(log).write(to: file, options: .atomic)
    }

    private var file: URL {
        let directory =
            (try? FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return directory.appending(path: "voice-log.json")
    }
}
