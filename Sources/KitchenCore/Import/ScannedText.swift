import Foundation

/// Text read from a scanned cookbook page, either from the PDF's own text layer or from text recognition.
/// Decides whether a text layer can be trusted and repairs what scans typically break (hyphenation, ligatures).
/// Reading the PDF and running the recognition stay in the app; everything here is plain text and testable on Linux.
public enum ScannedText {
    /// Where the text of a page came from.
    public enum Source: Sendable, Hashable {
        /// The text layer stored in the PDF, for example by the scanner's own OCR.
        case textLayer
        /// Text recognition on the rendered page, because the text layer was missing or unusable.
        case recognition
    }

    /// Fewer letters than this on the chosen pages means no real text layer (empty, or only a page number).
    static let minimumLetters = 80

    /// Whether a page's text layer is good enough to send on, or the page should be recognized from its image.
    /// Rejects empty layers, broken font encodings (replacement or private-use characters, letters that form no
    /// common German or English word) and layers that put a space between every letter.
    public static func isUsable(_ text: String) -> Bool {
        let scalars = text.unicodeScalars
        let letters = scalars.filter { CharacterSet.letters.contains($0) }.count
        guard letters >= minimumLetters else { return false }

        let visible = scalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
        let broken = visible.filter(isBroken).count
        if Double(broken) > Double(visible.count) * 0.02 { return false }
        if Double(letters) < Double(visible.count) * 0.6 { return false }

        let tokens = text.split(whereSeparator: { $0.isWhitespace })
        let singleLetters = tokens.filter { $0.count == 1 && $0.first?.isLetter == true }.count
        if Double(singleLetters) > Double(tokens.count) * 0.3 { return false }

        // Recipe text in German or English is full of short common words and units; a layer with shifted character
        // codes has letters but none of these.
        let common = tokens.filter { commonWords.contains($0.filter(\.isLetter).lowercased()) }.count
        return Double(common) >= Double(tokens.count) * 0.025
    }

    /// The pages as one text for the import: ligatures spelled out, soft hyphens removed, words split at a line
    /// end joined again, whitespace collapsed, pages separated by a blank line and the whole cut at
    /// `PlainText.maxCharacters`.
    public static func cleaned(pages: [String]) -> String {
        let text =
            pages
            .map(cleanedPage)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        return String(text.prefix(PlainText.maxCharacters))
    }

    static func cleanedPage(_ page: String) -> String {
        var text = page.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        for (ligature, letters) in ligatures {
            text = text.replacingOccurrences(of: ligature, with: letters)
        }
        text = text.replacingOccurrences(of: "\u{00AD}", with: "")
        let lines = text.components(separatedBy: .newlines)
            .map { $0.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ") }
            .filter { !$0.isEmpty }
        return joiningHyphenation(lines).joined(separator: "\n")
    }

    /// Joins a word split at a line end: "Zwie-" + "beln schälen" becomes "Zwiebeln schälen". A capital after
    /// the hyphen keeps it ("Kartoffel-Salat"), and so does a German coordination ("Zwiebel- und Knoblauchwürfel").
    static func joiningHyphenation(_ lines: [String]) -> [String] {
        var result: [String] = []
        for line in lines {
            guard let previous = result.last, let joined = joined(previous, line) else {
                result.append(line)
                continue
            }
            result[result.count - 1] = joined
        }
        return result
    }

    private static func joined(_ previous: String, _ next: String) -> String? {
        guard let hyphen = previous.last, hyphens.contains(hyphen) else { return nil }
        let head = previous.dropLast()
        guard let lastLetter = head.last, lastLetter.isLetter, let firstLetter = next.first, firstLetter.isLetter
        else { return nil }
        let firstWord = next.prefix { $0.isLetter }.lowercased()
        if coordinations.contains(firstWord) { return "\(head)- \(next)" }
        if firstLetter.isUppercase { return "\(head)-\(next)" }
        return "\(head)\(next)"
    }

    private static func isBroken(_ scalar: Unicode.Scalar) -> Bool {
        if scalar == "\u{FFFD}" || (0xE000...0xF8FF).contains(scalar.value) { return true }
        return CharacterSet.controlCharacters.contains(scalar)
            && !CharacterSet.whitespacesAndNewlines.contains(scalar)
    }

    private static let commonWords: Set<String> = [
        "und", "oder", "die", "der", "das", "den", "dem", "des", "ein", "eine", "einen", "mit", "in", "im", "auf",
        "für", "von", "zu", "zum", "zur", "bei", "aus", "nach", "dann", "etwas", "alles", "g", "kg", "ml", "l", "el",
        "tl", "prise", "stück", "min", "minuten", "the", "and", "or", "of", "to", "with", "a", "for", "cup", "cups",
        "tbsp", "tsp", "minutes", "add",
    ]
    /// "¬" is how some scanners mark a line-end hyphenation.
    private static let hyphens: Set<Character> = ["-", "‐", "¬"]
    private static let coordinations: Set<String> = ["und", "oder", "bzw", "sowie", "bis", "and", "or"]
    private static let ligatures: [(String, String)] = [
        ("ﬀ", "ff"), ("ﬁ", "fi"), ("ﬂ", "fl"), ("ﬃ", "ffi"), ("ﬄ", "ffl"), ("ﬅ", "st"), ("ﬆ", "st"),
    ]
}

/// The pages of a PDF chosen for an import. A recipe rarely spans more than a spread, so the choice is capped,
/// which also keeps text recognition and the request short.
public struct PageSelection: Sendable, Hashable {
    public static let maximum = 4

    public let pageCount: Int
    /// Zero-based page indices, ascending.
    public private(set) var pages: [Int]

    /// Starts with the first page chosen, or nothing for an empty document.
    public init(pageCount: Int) {
        self.pageCount = max(0, pageCount)
        pages = pageCount > 0 ? [0] : []
    }

    public func contains(_ page: Int) -> Bool { pages.contains(page) }

    /// Whether `maximum` pages are chosen, so no further page can be added.
    public var isFull: Bool { pages.count >= Self.maximum }

    /// Adds or removes `page`. Pages outside the document, and new pages once `maximum` is reached, are ignored.
    public mutating func toggle(_ page: Int) {
        guard (0..<pageCount).contains(page) else { return }
        if let index = pages.firstIndex(of: page) {
            pages.remove(at: index)
        } else if !isFull {
            pages.append(page)
            pages.sort()
        }
    }
}
