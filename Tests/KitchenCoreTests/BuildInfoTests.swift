import Foundation
import Testing

@testable import KitchenCore

@Suite("Build info")
struct BuildInfoTests {
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    @Test func readsCleanBuild() {
        let info = BuildInfo(infoDictionary: [
            "CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "1",
            BuildInfo.commitKey: "b5b2b18", BuildInfo.commitDateKey: "2026-10-28",
        ])
        #expect(info.version == "0.1.0")
        #expect(info.build == "1")
        #expect(info.commit == "b5b2b18")
        #expect(!info.hasLocalChanges)
        #expect(info.commitDate == Self.utc.date(from: DateComponents(year: 2026, month: 10, day: 28)))
    }

    @Test func stripsDirtyMarker() {
        let info = BuildInfo(infoDictionary: [BuildInfo.commitKey: "b5b2b18+"])
        #expect(info.commit == "b5b2b18")
        #expect(info.hasLocalChanges)
    }

    @Test(arguments: ["", " ", "unknown", "+", "unknown+"])
    func treatsMissingCommitAsNil(_ raw: String) {
        let info = BuildInfo(infoDictionary: [BuildInfo.commitKey: raw])
        #expect(info.commit == nil)
        #expect(!info.hasLocalChanges)
    }

    @Test(arguments: ["", "2026-13-01", "2026-02-30", "28.10.2026", "2026-10"])
    func rejectsBadDates(_ raw: String) {
        #expect(BuildInfo(infoDictionary: [BuildInfo.commitDateKey: raw]).commitDate == nil)
    }

    @Test func emptyDictionaryHasNothing() {
        #expect(BuildInfo(infoDictionary: [:]) == BuildInfo(version: nil, build: nil, commit: nil))
    }

    @Test func ignoresNonStringValues() {
        #expect(BuildInfo(infoDictionary: ["CFBundleVersion": 42]).build == nil)
    }
}
