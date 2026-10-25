import Foundation

/// What the voice mode heard and what it made of it, to tune the command rules from real kitchen sentences.
public struct VoiceLog: Sendable, Equatable, Codable {
    public struct Entry: Sendable, Equatable, Codable {
        public var date: Date
        public var heard: String
        /// The command `VoiceCommand.parse` found, nil when the sentence was ignored.
        public var command: String?
        public var reply: String?

        public init(date: Date, heard: String, command: String?, reply: String? = nil) {
            self.date = date
            self.heard = heard
            self.command = command
            self.reply = reply
        }
    }

    /// Oldest first.
    public private(set) var entries: [Entry]
    public let capacity: Int

    public init(entries: [Entry] = [], capacity: Int = 500) {
        self.capacity = capacity
        self.entries = Array(entries.suffix(capacity))
    }

    /// Adds `entry` and drops the oldest ones beyond the capacity.
    public mutating func append(_ entry: Entry) {
        entries.append(entry)
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
    }

    /// Fills in the reply of the newest entry, once it is known.
    public mutating func setLastReply(_ reply: String) {
        guard !entries.isEmpty else { return }
        entries[entries.count - 1].reply = reply
    }

    public mutating func removeAll() {
        entries.removeAll()
    }

    /// One tab-separated line per entry, oldest first: time, heard, command or "ignoriert", reply. Easy to paste
    /// into a chat or a spreadsheet.
    public func exportText() -> String {
        let formatter = ISO8601DateFormatter()
        return entries.map { entry in
            [formatter.string(from: entry.date), entry.heard, entry.command ?? "ignoriert", entry.reply ?? ""]
                .map { $0.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ") }
                .joined(separator: "\t")
        }
        .joined(separator: "\n")
    }
}

extension VoiceCommand {
    /// A short stable name for the log, for example "weiter" or "ersatz: kokosmilch".
    public var logName: String {
        switch self {
        case .next: "weiter"
        case .previous: "zurück"
        case .repeatStep: "wiederholen"
        case .remainingTime: "restzeit"
        case .startTimer: "timer start"
        case .pauseTimer: "timer pause"
        case .stepIngredients: "zutaten"
        case .substitute(let ingredient, let addressed):
            addressed ? "omni ersatz: \(ingredient)" : "ersatz: \(ingredient)"
        case .question: "omni frage"
        }
    }
}
