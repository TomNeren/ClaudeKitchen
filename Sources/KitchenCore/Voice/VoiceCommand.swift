import Foundation

/// What a spoken sentence asks for during a cook.
///
/// The app listens all the time while the cooking mode is open, so talk in the kitchen must not trigger anything by
/// accident: a fixed command only counts when the sentence is essentially that command, a substitution only in a
/// short sentence (and the app stays silent when the ingredient is not in the recipe), and free questions only after
/// the wake word "Omni".
public enum VoiceCommand: Sendable, Equatable {
    case next
    case previous
    case repeatStep
    case remainingTime
    case startTimer
    case pauseTimer
    case stepIngredients
    /// "Mir fehlt Feta", "Was kann ich statt Kokosmilch nehmen?". `addressed` when said after the wake word: then an
    /// ingredient that is not in the recipe deserves an answer, otherwise the sentence was probably conversation.
    case substitute(ingredient: String, addressed: Bool = false)
    /// Anything else said after the wake word, for the language model.
    case question(String)

    public static let wakeWord = "omni"

    /// Words besides the command phrase that still count as a command ("weiter bitte", "ok timer starten").
    static let maxExtraWords = 2
    /// Longer sentences without the wake word are conversation, even with "mir fehlt" in them.
    static let maxSubstitutionWords = 8

    public static func parse(_ transcript: String) -> VoiceCommand? {
        var words = normalizedWords(transcript)
        let addressed = words.first == wakeWord || (words.first == "hey" && words.dropFirst().first == wakeWord)
        if addressed {
            words.removeFirst(words.first == "hey" ? 2 : 1)
        }
        guard !words.isEmpty else { return nil }

        if let command = fixedCommand(in: words) {
            return command
        }
        if addressed {
            // "Omni, kann ich statt Spinat Mangold nehmen?" is a question for the model, which also knows the
            // curated substitutes; only the plain forms stay substitutions.
            if let ingredient = substitution(in: words, markers: plainSubstitutionMarkers) {
                return .substitute(ingredient: ingredient, addressed: true)
            }
            return .question(cleaned(transcript, droppingLeading: transcript.lowercased().hasPrefix("hey") ? 2 : 1))
        }
        guard words.count <= maxSubstitutionWords else { return nil }
        return substitution(in: words, markers: plainSubstitutionMarkers + insteadMarkers)
            .map { .substitute(ingredient: $0) }
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

    /// The first pattern found as whole words in a sentence that is not much more than that pattern; "pause" wins
    /// over "start" by order. "Was mache ich, wenn der Reis nicht fertig ist?" is not "fertig".
    private static func fixedCommand(in words: [String]) -> VoiceCommand? {
        let padded = " \(words.joined(separator: " ")) "
        for (command, phrases) in patterns {
            let fits = phrases.contains { phrase in
                padded.contains(" \(phrase) ")
                    && words.count - phrase.split(separator: " ").count <= maxExtraWords
            }
            if fits { return command }
        }
        return nil
    }

    private static let plainSubstitutionMarkers = [
        " mir fehlt ", " mir fehlen ", " ich habe keine ", " ich habe keinen ", " ich habe kein ", " hab keine ",
        " hab keinen ", " hab kein ", " ersatz fur ",
    ]
    private static let insteadMarkers = [" statt ", " anstelle von ", " anstatt "]

    /// The words after a marker such as "mir fehlt X" or "statt X", up to a verb like "nehmen".
    private static func substitution(in words: [String], markers: [String]) -> String? {
        let sentence = " " + words.joined(separator: " ") + " "
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
        TextFold.words(text).map { $0.lowercased() }
    }

    private static func cleaned(_ transcript: String, droppingLeading count: Int) -> String {
        let words = transcript.split(whereSeparator: \.isWhitespace).dropFirst(count)
        return words.joined(separator: " ").trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
    }
}

extension CookingSession {
    /// The recipe ingredient a spoken name means, matched without case and diacritics: the whole name first, then
    /// the ingredient sharing the most words with it ("Linsen" finds "Rote Linsen", "frischen Ingwer" finds "Ingwer",
    /// "Spinat" finds "Blattspinat"). Nil when no word matches, so "keine Ahnung" finds nothing.
    public func ingredient(named spoken: String) -> Ingredient? {
        let wanted = VoiceCommand.normalizedWords(spoken)
        guard !wanted.isEmpty else { return nil }
        let candidates = recipe.ingredients.map { ($0, VoiceCommand.normalizedWords($0.name)) }
        if let exact = candidates.first(where: { $0.1 == wanted }) {
            return exact.0
        }
        let meaningful = wanted.filter { $0.count >= 3 && !Self.fillerWords.contains($0) }
        // German compounds: "Spinat" means "Blattspinat". Short words must match from the start ("Ei" is not in
        // "Zwiebel").
        let scored = candidates.map { candidate in
            let hits = meaningful.count(where: { word in
                candidate.1.contains { word.count >= 4 ? $0.contains(word) : $0.hasPrefix(word) }
            })
            return (candidate.0, hits)
        }
        guard let best = scored.max(by: { $0.1 < $1.1 }), best.1 > 0 else { return nil }
        return scored.first { $0.1 == best.1 }?.0
    }

    private static let fillerWords: Set = [
        "noch", "mehr", "mal", "haus", "hause", "gerade", "leider", "bitte", "wann", "was", "wie", "ich", "mir",
        "frisch",
        "frische", "frischen", "frischer",
    ]
}

extension CookingSession {
    /// The curated substitutes of `ingredient` with the amounts to use for the current servings.
    public func substitutions(for ingredient: Ingredient) -> [(substitute: Substitute, amount: Amount)] {
        ingredient.substitutions(from: recipe.baseServings, to: servings)
    }
}
