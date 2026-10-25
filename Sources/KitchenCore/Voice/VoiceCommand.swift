import Foundation

/// What a spoken sentence asks for during a cook.
///
/// The app listens all the time while the cooking mode is open, so talk in the kitchen must not trigger anything by
/// accident: a fixed command only counts when the sentence is short and is essentially that command, and free
/// questions only count after the wake word "Omni".
public enum VoiceCommand: Sendable, Equatable {
    case next
    case previous
    case repeatStep
    case remainingTime
    case startTimer
    case pauseTimer
    case stepIngredients
    /// "Mir fehlt Feta", "Was kann ich statt Kokosmilch nehmen?"
    case substitute(ingredient: String)
    /// Anything else said after the wake word, for the language model.
    case question(String)

    public static let wakeWord = "omni"

    /// Sentences longer than this, without the wake word, are taken as conversation and ignored.
    static let maxCommandWords = 6

    public static func parse(_ transcript: String) -> VoiceCommand? {
        var words = normalizedWords(transcript)
        let addressed = words.first == wakeWord || (words.first == "hey" && words.dropFirst().first == wakeWord)
        if addressed {
            words.removeFirst(words.first == "hey" ? 2 : 1)
        }
        guard !words.isEmpty else { return nil }
        let sentence = words.joined(separator: " ")

        if let ingredient = substitution(in: words) {
            return .substitute(ingredient: ingredient)
        }
        if addressed || words.count <= maxCommandWords, let command = fixedCommand(in: sentence) {
            return command
        }
        return addressed
            ? .question(cleaned(transcript, droppingLeading: transcript.lowercased().hasPrefix("hey") ? 2 : 1)) : nil
    }

    private static let patterns: [(VoiceCommand, [String])] = [
        (.previous, ["zuruck", "vorheriger schritt", "schritt zuruck", "einen schritt zuruck", "noch mal zuruck"]),
        (
            .next,
            ["weiter", "nachster schritt", "nachster", "was kommt jetzt", "was ist der nachste schritt", "fertig"]
        ),
        (.repeatStep, ["wiederholen", "nochmal", "noch mal", "was war das", "wie bitte", "was muss ich machen"]),
        (.remainingTime, ["wie lange noch", "wie lange", "restzeit", "wie viel zeit", "wieviel zeit"]),
        (.pauseTimer, ["timer pausieren", "timer anhalten", "timer stopp", "pause"]),
        (.startTimer, ["timer starten", "timer start", "starte den timer", "timer los", "los"]),
        (.stepIngredients, ["welche zutaten", "was kommt rein", "was brauche ich", "zutaten"]),
    ]

    /// The first pattern found as whole words in the sentence; "pause" wins over "start" by order.
    private static func fixedCommand(in sentence: String) -> VoiceCommand? {
        let padded = " \(sentence) "
        for (command, phrases) in patterns where phrases.contains(where: { padded.contains(" \($0) ") }) {
            return command
        }
        return nil
    }

    /// "mir fehlt X", "ich habe kein(e/en) X", "statt X", "ersatz fur X", "anstelle von X".
    private static func substitution(in words: [String]) -> String? {
        let sentence = " " + words.joined(separator: " ") + " "
        let markers = [
            " mir fehlt ", " mir fehlen ", " ich habe keine ", " ich habe keinen ", " ich habe kein ", " hab keine ",
            " hab keinen ", " hab kein ", " statt ", " anstelle von ", " anstatt ", " ersatz fur ",
        ]
        for marker in markers {
            guard let range = sentence.range(of: marker) else { continue }
            let rest = sentence[range.upperBound...].split(separator: " ").map(String.init)
            let stop: Set = ["nehmen", "verwenden", "benutzen", "machen", "da", "mehr", "was", "kann", "ich", "nehme"]
            let ingredient = rest.prefix { !stop.contains($0) }.filter {
                !["den", "die", "das", "der", "dem"].contains($0)
            }
            if !ingredient.isEmpty {
                return ingredient.joined(separator: " ")
            }
        }
        return nil
    }

    /// Lowercased, without diacritics and punctuation, umlauts folded ("nächster" -> "nachster").
    static func normalizedWords(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "ß", with: "ss")
            .split { !($0.isLetter || $0.isNumber) }
            .map { $0.lowercased() }
    }

    private static func cleaned(_ transcript: String, droppingLeading count: Int) -> String {
        let words = transcript.split(whereSeparator: \.isWhitespace).dropFirst(count)
        return words.joined(separator: " ").trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
    }
}

extension CookingSession {
    /// The recipe ingredient a spoken name means, matched without case and diacritics, by whole name first, then by
    /// words of the name ("Linsen" finds "Rote Linsen", "Spinat" finds "Blattspinat").
    public func ingredient(named spoken: String) -> Ingredient? {
        let wanted = VoiceCommand.normalizedWords(spoken)
        guard !wanted.isEmpty else { return nil }
        let candidates = recipe.ingredients.map { ($0, VoiceCommand.normalizedWords($0.name)) }
        if let exact = candidates.first(where: { $0.1 == wanted }) {
            return exact.0
        }
        // German compounds: "Spinat" means "Blattspinat". Short words must match from the start ("Ei" is not in
        // "Zwiebel").
        return candidates.first { candidate in
            wanted.allSatisfy { word in
                candidate.1.contains { word.count >= 4 ? $0.contains(word) : $0.hasPrefix(word) }
            }
        }?.0
    }
}

extension CookingSession {
    /// The curated substitutes of `ingredient` with the amounts to use for the current servings.
    public func substitutions(for ingredient: Ingredient) -> [(substitute: Substitute, amount: Amount)] {
        ingredient.substitutions(from: recipe.baseServings, to: servings)
    }
}
