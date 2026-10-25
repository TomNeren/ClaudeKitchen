import Foundation

/// Reduces a web page to the text a recipe import needs, so the request stays small.
public enum PlainText {
    /// Upper bound for the text sent to the model; recipe pages rarely need more.
    public static let maxCharacters = 20_000

    /// Drops scripts, styles and tags, decodes entities, collapses whitespace and cuts at `maxCharacters`.
    /// Structured recipe data (`application/ld+json`) is kept in front, it is often the cleanest source on a page.
    public static func fromHTML(_ html: String) -> String {
        let structured = structuredData(in: html)
        var text = html
        for element in ["script", "style", "noscript", "svg", "head"] {
            text = text.replacingOccurrences(
                of: "<\(element)[^>]*>[\\s\\S]*?</\(element)>", with: " ",
                options: [.regularExpression, .caseInsensitive])
        }
        text = text.replacingOccurrences(
            of: "<(br|/p|/li|/h[1-6]|/div|/tr)[^>]*>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        text = decodeEntities(text)
        let lines = (structured + text.components(separatedBy: .newlines))
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { !$0.isEmpty }
        return String(lines.joined(separator: "\n").prefix(maxCharacters))
    }

    /// The JSON-LD blocks of the page, one per line.
    private static func structuredData(in html: String) -> [String] {
        guard
            let expression = try? NSRegularExpression(
                pattern: "<script[^>]*application/ld\\+json[^>]*>([\\s\\S]*?)</script>", options: [.caseInsensitive])
        else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        return expression.matches(in: html, range: range).compactMap { match in
            Range(match.range(at: 1), in: html).map { String(html[$0]) }
        }
    }

    /// Named entities first, then numeric ones (`&#228;`, `&#xE4;`), and `&amp;` last so `&amp;lt;` stays `&lt;`.
    static func decodeEntities(_ input: String) -> String {
        var text = input
        for (entity, character) in entities {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        if let expression = try? NSRegularExpression(pattern: "&#(x?)([0-9a-fA-F]+);") {
            for match in expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
                guard let whole = Range(match.range, in: text), let hex = Range(match.range(at: 1), in: text),
                    let digits = Range(match.range(at: 2), in: text),
                    let value = UInt32(text[digits], radix: text[hex].isEmpty ? 10 : 16),
                    let scalar = Unicode.Scalar(value)
                else { continue }
                text.replaceSubrange(whole, with: String(Character(scalar)))
            }
        }
        return text.replacingOccurrences(of: "&amp;", with: "&")
    }

    private static let entities: [(String, String)] = [
        ("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"),
        ("&auml;", "ä"), ("&ouml;", "ö"), ("&uuml;", "ü"), ("&Auml;", "Ä"), ("&Ouml;", "Ö"), ("&Uuml;", "Ü"),
        ("&szlig;", "ß"), ("&deg;", "°"), ("&frac12;", "½"),
    ]
}
