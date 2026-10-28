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
    /// "Was ist Garam Masala?", "Woraus besteht Khmeli Suneli?": answered from the spice guide. `addressed` as for
    /// `substitute`: after the wake word a name the guide does not know goes to the language model as a question.
    case explain(ingredient: String, addressed: Bool = false)
    /// Anything else said after the wake word, for the language model.
    case question(String)

    public static let wakeWord = "omni"

    /// Words besides the command phrase that still count as a command ("weiter bitte", "ok timer starten").
    static let maxExtraWords = 2
    /// Longer sentences without the wake word are conversation, even with "mir fehlt" in them.
    static let maxSubstitutionWords = 8

    /// What the transcriber hands over as one result can hold several sentences ("Weiter. Wie lange noch?"), which
    /// as a whole are too long for a command. Each sentence is parsed on its own; a wake word said as a sentence of
    /// its own ("Omni. Wie lange hält sich das?") addresses the sentence after it.
    public static func parseSentences(_ transcript: String) -> [(sentence: String, command: VoiceCommand?)] {
        var result: [(sentence: String, command: VoiceCommand?)] = []
        var pendingWake: String?
        for sentence in sentences(in: transcript) {
            if isOnlyWakeWord(sentence) {
                pendingWake = [pendingWake, sentence].compactMap { $0 }.joined(separator: " ")
                continue
            }
            let addressed = pendingWake.map { "\($0) \(sentence)" } ?? sentence
            pendingWake = nil
            result.append((addressed, parse(addressed)))
        }
        if let pendingWake {
            result.append((pendingWake, nil))
        }
        return result
    }

    public static func parse(_ transcript: String) -> VoiceCommand? {
        var words = normalizedWords(transcript)
        let lead = wakeLead(in: words)
        let addressed = lead > 0
        words.removeFirst(lead)
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
            if let ingredient = explained(in: words) {
                return .explain(ingredient: ingredient, addressed: true)
            }
            return .question(cleaned(transcript, droppingLeading: lead))
        }
        guard words.count <= maxSubstitutionWords else { return nil }
        if let ingredient = substitution(in: words, markers: plainSubstitutionMarkers + insteadMarkers) {
            return .substitute(ingredient: ingredient)
        }
        return explained(in: words).map { .explain(ingredient: $0) }
    }

    /// Longest first, so "was ist eigentlich" is not read as "was ist" plus "eigentlich".
    private static let explainMarkers = [
        "was ist eigentlich", "was sind eigentlich", "was steckt in", "woraus besteht", "woraus bestehen",
        "was ist denn", "was ist", "was sind",
    ]

    /// The name in a sentence that starts with "was ist" or "woraus besteht", without articles and "drin".
    private static func explained(in words: [String]) -> String? {
        let sentence = words.joined(separator: " ") + " "
        guard let marker = explainMarkers.first(where: { sentence.hasPrefix($0 + " ") }) else { return nil }
        let skip: Set = ["eigentlich", "denn", "genau", "in", "drin", "das", "der", "die", "dem", "den", "ein", "eine"]
        let name = words.dropFirst(marker.split(separator: " ").count).filter { !skip.contains($0) }
        return name.isEmpty ? nil : name.joined(separator: " ")
    }

    /// The sentence without a leading "Omni" (and "Hey", "Okay" before it), for handing it to the language model.
    public static func withoutWakeWord(_ transcript: String) -> String {
        cleaned(transcript, droppingLeading: wakeLead(in: normalizedWords(transcript)))
    }

    /// How the transcriber writes "Omni" besides the word itself.
    static let wakeWordVariants: Set = [wakeWord, "omnie", "omny", "homni", "ommi", "omnis"]
    /// Words that may come before the wake word ("Okay Omni", "Hey Omni").
    private static let wakeOpeners: Set = ["hey", "hallo", "ok", "okay", "also", "ja", "so"]

    /// The number of leading words up to and including the wake word, 0 when the sentence does not start with it.
    private static func wakeLead(in words: [String]) -> Int {
        let openers = words.prefix { wakeOpeners.contains($0) }.count
        guard openers <= 2, openers < words.count, wakeWordVariants.contains(words[openers]) else { return 0 }
        return openers + 1
    }

    private static func isOnlyWakeWord(_ sentence: String) -> Bool {
        let words = normalizedWords(sentence)
        return !words.isEmpty && wakeLead(in: words) == words.count
    }

    /// The sentences of a transcript, split after ".", "!", "?" and ";" when a space or the end follows, so "2.5"
    /// stays one number.
    static func sentences(in transcript: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        var previousWasTerminator = false
        for character in transcript {
            if previousWasTerminator, character.isWhitespace {
                sentences.append(current)
                current = ""
                previousWasTerminator = false
                continue
            }
            current.append(character)
            previousWasTerminator = ".!?;".contains(character)
        }
        sentences.append(current)
        return sentences.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !normalizedWords($0).isEmpty }
    }

    private static let patterns: [(VoiceCommand, [String])] = [
        (
            .previous,
            [
                "zuruck", "vorheriger schritt", "vorherigen schritt", "schritt zuruck", "einen schritt zuruck",
                "noch mal zuruck", "schritt davor",
            ]
        ),
        (
            .next,
            [
                "weiter", "nachster schritt", "nachsten schritt", "nachster", "was kommt jetzt",
                "was ist der nachste schritt", "fertig", "erledigt",
            ]
        ),
        (
            .repeatStep,
            [
                "wiederholen", "wiederhole", "nochmal", "noch mal", "noch einmal", "was war das", "wie bitte",
                "was muss ich machen", "was muss ich tun", "was soll ich machen", "was soll ich tun", "vorlesen",
                "lies vor",
            ]
        ),
        (
            .remainingTime,
            [
                "wie lange noch", "wie lange", "wie lang noch", "wie lange dauert es noch", "wie lange dauert das noch",
                "wie lange braucht das noch", "restzeit", "wie viel zeit", "wieviel zeit", "wann ist der timer fertig",
            ]
        ),
        (.pauseTimer, ["timer pausieren", "timer anhalten", "timer stopp", "timer stoppen", "pause"]),
        (
            .startTimer,
            ["timer starten", "timer start", "starte den timer", "starte timer", "timer an", "timer los", "los"]
        ),
        (.stepIngredients, ["welche zutaten", "was kommt rein", "was brauche ich", "zutaten"]),
    ]

    /// Words that do not make a sentence longer than its command: "Okay, dann jetzt bitte weiter" is "weiter".
    private static let fillerWords: Set = [
        "ok", "okay", "bitte", "jetzt", "dann", "mal", "also", "ah", "ahm", "hm", "ja", "so", "und", "gut", "danke",
        "na",
    ]

    /// The first pattern found as whole words in a sentence that is not much more than that pattern, filler words
    /// aside; "pause" wins over "start" by order. "Was mache ich, wenn der Reis nicht fertig ist?" is not "fertig".
    private static func fixedCommand(in words: [String]) -> VoiceCommand? {
        let padded = " \(words.joined(separator: " ")) "
        let fillers = words.count(where: fillerWords.contains)
        for (command, phrases) in patterns {
            let fits = phrases.contains { phrase in
                let phraseWords = phrase.split(separator: " ").map(String.init)
                let extras =
                    (words.count - phraseWords.count) - (fillers - phraseWords.count(where: fillerWords.contains))
                return padded.contains(" \(phrase) ") && extras <= maxExtraWords
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
