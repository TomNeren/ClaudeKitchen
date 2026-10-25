import Foundation

/// Reduces a web page to the text a recipe import needs, so the request stays small.
public enum PlainText {
    /// Upper bound for the text sent to the model; recipe pages rarely need more.
    public static let maxCharacters = 20_000

    /// Drops scripts, styles and tags, decodes common entities, collapses whitespace and cuts at `maxCharacters`.
    public static func fromHTML(_ html: String) -> String {
        var text = html
        for element in ["script", "style", "noscript", "svg", "head"] {
            text = text.replacingOccurrences(
                of: "<\(element)[^>]*>[\\s\\S]*?</\(element)>", with: " ",
                options: [.regularExpression, .caseInsensitive])
        }
        text = text.replacingOccurrences(
            of: "<(br|/p|/li|/h[1-6]|/div|/tr)[^>]*>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        for (entity, character) in entities {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        let lines = text.components(separatedBy: .newlines)
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { !$0.isEmpty }
        return String(lines.joined(separator: "\n").prefix(maxCharacters))
    }

    private static let entities: [(String, String)] = [
        ("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"),
        ("&auml;", "ä"), ("&ouml;", "ö"), ("&uuml;", "ü"), ("&Auml;", "Ä"), ("&Ouml;", "Ö"), ("&Uuml;", "Ü"),
        ("&szlig;", "ß"), ("&deg;", "°"), ("&frac12;", "½"),
    ]
}
