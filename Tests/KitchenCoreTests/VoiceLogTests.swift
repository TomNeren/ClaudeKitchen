import Foundation
import Testing

@testable import KitchenCore

@Suite("Voice log")
struct VoiceLogTests {
    private let date = Date(timeIntervalSince1970: 0)

    @Test func keepsOnlyTheNewestEntries() {
        var log = VoiceLog(capacity: 2)
        for word in ["eins", "zwei", "drei"] {
            log.append(.init(date: date, heard: word, command: nil))
        }
        #expect(log.entries.map(\.heard) == ["zwei", "drei"])
    }

    @Test func exportsOneLinePerEntryWithIgnoredMarked() {
        var log = VoiceLog()
        log.append(.init(date: date, heard: "Weiter", command: VoiceCommand.next.logName))
        log.setLastReply("Schritt 2\nvon 6")
        log.append(.init(date: date, heard: "Wo ist\tdas Salz", command: nil))
        #expect(
            log.exportText()
                == "1970-01-01T00:00:00Z\tWeiter\tweiter\tSchritt 2 von 6\n1970-01-01T00:00:00Z\tWo ist das Salz\tignoriert\t"
        )
    }

    @Test func roundTripsThroughJSON() throws {
        var log = VoiceLog(capacity: 3)
        log.append(.init(date: date, heard: "Mir fehlt Feta", command: "ersatz: feta", reply: nil))
        let decoded = try JSONDecoder().decode(VoiceLog.self, from: JSONEncoder().encode(log))
        #expect(decoded == log)
    }
}
