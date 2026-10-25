import Foundation

/// One line of an ingredient list as people write it: "200 g Rote Linsen", "1,5 kg Kartoffeln", "½ TL Kurkuma",
/// "2 Zehen Knoblauch", "3 Eier (Größe M)", "Salz". Lets the editor take typed or pasted lists.
public struct IngredientLine: Sendable, Equatable {
    public var name: String
    public var amount: Amount
    public var note: String?

    public init(name: String, amount: Amount, note: String? = nil) {
        self.name = name
        self.amount = amount
        self.note = note
    }

    /// Nil for a line without a name, for example an empty line or "200 g".
    public static func parse(_ line: String) -> IngredientLine? {
        var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        // List markers from pasted recipes: "- ", "• ", "* ".
        while let first = text.first, "-•*–".contains(first) {
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        // Numbered lists: "1. 200 g Mehl", "2) 1 Zwiebel". A decimal like "1.5 kg" has no space after the dot.
        if let marker = text.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) {
            text = String(text[marker.upperBound...])
        }
        var note: String?
        if let open = text.firstIndex(of: "("), let close = text[open...].firstIndex(of: ")") {
            let inner = text[text.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
            note = inner.isEmpty ? nil : inner
            text = (text[..<open] + text[text.index(after: close)...]).trimmingCharacters(in: .whitespaces)
        }

        var words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return nil }

        // "200g" is "200 g".
        if let first = words.first, let split = splitNumberAndUnit(first) {
            words.replaceSubrange(0...0, with: split)
        }
        guard var value = number(words[0]) else {
            let name = words.joined(separator: " ")
            let toTaste = toTasteWords.contains(words[0].lowercased())
            return IngredientLine(
                name: toTaste ? strippedToTaste(words) : name, amount: .toTaste, note: note)
        }
        words.removeFirst()
        // "1 ½ TL", "1 1/2 EL": a fraction after the whole number belongs to it.
        if value == value.rounded(), let next = words.first, let fraction = number(next), fraction < 1 {
            value += fraction
            words.removeFirst()
        }
        // "1 Prise Salz", "1 Msp. Muskat" are to taste.
        if let next = words.first,
            toTasteWords.contains(next.lowercased().trimmingCharacters(in: .punctuationCharacters))
        {
            let name = words.dropFirst().joined(separator: " ")
            return name.isEmpty ? nil : IngredientLine(name: name, amount: .toTaste, note: note)
        }
        var amount = Amount.measured(value, .piece)
        if let unitWord = words.first, let (unit, factor) = unit(unitWord) {
            amount = .measured(value * factor, unit)
            words.removeFirst()
        }
        let name = words.joined(separator: " ").trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        guard !name.isEmpty else { return nil }
        return IngredientLine(name: name, amount: amount, note: note)
    }

    /// Every line of a pasted list that has a name, in order.
    public static func parseList(_ text: String) -> [IngredientLine] {
        text.split(whereSeparator: \.isNewline).compactMap { parse(String($0)) }
    }

    private static let toTasteWords: Set = ["prise", "prisen", "etwas", "nach", "msp", "messerspitze"]

    private static let fractions: [Character: Double] = ["½": 0.5, "¼": 0.25, "¾": 0.75, "⅓": 1.0 / 3, "⅔": 2.0 / 3]

    /// "200", "1,5", "1.5", "½", "1½", "1/2".
    static func number(_ word: String) -> Double? {
        // "1.000" is German for a thousand; only then do dots group digits.
        let grouped = word.range(of: #"^\d{1,3}(\.\d{3})+$"#, options: .regularExpression) != nil
        let text = (grouped ? word.replacingOccurrences(of: ".", with: "") : word)
            .replacingOccurrences(of: ",", with: ".")
        if let value = Double(text), value > 0 { return value }
        if let last = text.last, let fraction = fractions[last] {
            let whole = text.dropLast()
            if whole.isEmpty { return fraction }
            return Double(whole).map { $0 + fraction }
        }
        let parts = text.split(separator: "/")
        if parts.count == 2, let top = Double(parts[0]), let bottom = Double(parts[1]), bottom > 0 {
            return top / bottom
        }
        return nil
    }

    private static func splitNumberAndUnit(_ word: String) -> [String]? {
        guard let index = word.firstIndex(where: { $0.isLetter }), index != word.startIndex else { return nil }
        let head = String(word[..<index])
        let tail = String(word[index...])
        guard number(head) != nil, unit(tail) != nil else { return nil }
        return [head, tail]
    }

    /// Units and how many of the target unit one of them is. Litres and millilitres count as grams.
    private static func unit(_ word: String) -> (MeasureUnit, Double)? {
        switch word.lowercased().trimmingCharacters(in: .punctuationCharacters) {
        case "g", "gr", "gramm": (.gram, 1)
        case "kg", "kilo": (.gram, 1000)
        case "ml": (.gram, 1)
        case "l", "liter": (.gram, 1000)
        case "tl", "teelöffel", "teeloffel": (.teaspoon, 1)
        case "el", "esslöffel", "essloffel": (.tablespoon, 1)
        case "stk", "stück", "stuck": (.piece, 1)
        case "zehe", "zehen": (.clove, 1)
        default: nil
        }
    }

    /// "Prise Salz" is "Salz", "etwas Pfeffer" is "Pfeffer", "nach Geschmack Salz" is "Salz".
    private static func strippedToTaste(_ words: [String]) -> String {
        var rest = words.dropFirst()
        if words[0].lowercased() == "nach", rest.first?.lowercased() == "geschmack" { rest = rest.dropFirst() }
        return rest.isEmpty ? words.joined(separator: " ") : rest.joined(separator: " ")
    }
}
