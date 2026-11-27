import Foundation

/// Which build of the app is installed: marketing version, build number and the git commit it was built from.
/// A build phase in the app writes the commit into the built Info.plist, so a device shows the exact state.
public struct BuildInfo: Sendable, Equatable {
    /// Info.plist key holding the short commit hash, with a trailing "+" when the working tree had changes.
    public static let commitKey = "GitCommit"
    /// Info.plist key holding the commit date as an ISO date ("2026-10-28").
    public static let commitDateKey = "GitCommitDate"

    public var version: String?
    public var build: String?
    /// Short commit hash without the dirty marker.
    public var commit: String?
    /// The build contained uncommitted changes.
    public var hasLocalChanges: Bool
    public var commitDate: Date?

    public init(
        version: String?, build: String?, commit: String?, hasLocalChanges: Bool = false, commitDate: Date? = nil
    ) {
        self.version = version
        self.build = build
        self.commit = commit
        self.hasLocalChanges = hasLocalChanges
        self.commitDate = commitDate
    }

    /// Reads the values from an Info.plist dictionary, usually `Bundle.main.infoDictionary`.
    /// Empty strings and an unknown commit count as missing.
    public init(infoDictionary: [String: Any]) {
        func value(_ key: String) -> String? {
            guard let text = (infoDictionary[key] as? String)?.trimmingCharacters(in: .whitespaces), !text.isEmpty
            else { return nil }
            return text
        }
        var commit = value(Self.commitKey)
        let dirty = commit?.hasSuffix("+") ?? false
        if dirty { commit?.removeLast() }
        if commit?.isEmpty == true || commit == "unknown" { commit = nil }
        self.init(
            version: value("CFBundleShortVersionString"),
            build: value("CFBundleVersion"),
            commit: commit,
            hasLocalChanges: commit != nil && dirty,
            commitDate: value(Self.commitDateKey).flatMap(Self.parseDate)
        )
    }

    private static func parseDate(_ text: String) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = calendar.date(from: components),
            calendar.dateComponents([.year, .month, .day], from: date) == components
        else { return nil }
        return date
    }
}
