import Testing

@testable import KitchenCore

@Suite("Voice commands")
struct VoiceCommandTests {
    @Test(arguments: [
        ("Weiter", VoiceCommand.next), ("Nächster Schritt!", .next), ("Was kommt jetzt?", .next),
        ("Zurück", .previous), ("Einen Schritt zurück bitte", .previous),
        ("Noch mal", .repeatStep), ("Wie bitte?", .repeatStep),
        ("Wie lange noch?", .remainingTime), ("Timer starten", .startTimer), ("Timer pausieren", .pauseTimer),
        ("Pause", .pauseTimer), ("Welche Zutaten?", .stepIngredients),
        ("Omni, weiter", .next), ("Hey Omni wie lange noch", .remainingTime),
        ("Okay, Timer starten bitte", .startTimer),
    ])
    func recognisesShortCommands(spoken: String, expected: VoiceCommand) {
        #expect(VoiceCommand.parse(spoken) == expected)
    }

    @Test func ignoresConversation() {
        #expect(VoiceCommand.parse("Und dann sind wir einfach weiter gefahren bis zum Strand") == nil)
        #expect(VoiceCommand.parse("Kannst du mir mal kurz das Salz geben") == nil)
        #expect(VoiceCommand.parse("") == nil)
        #expect(VoiceCommand.parse("Omni") == nil)
        #expect(VoiceCommand.parse("Ich habe keine Ahnung, wann die anderen kommen und was sie mitbringen") == nil)
    }

    @Test(arguments: [
        (
            "Omni, was mache ich, wenn der Reis noch nicht fertig ist?",
            "was mache ich, wenn der Reis noch nicht fertig ist"
        ),
        ("Omni, wie lange kann ich das lagern?", "wie lange kann ich das lagern"),
        ("Omni, welche Zutaten kann ich weglassen?", "welche Zutaten kann ich weglassen"),
        ("Omni, kann ich statt Spinat Mangold nehmen?", "kann ich statt Spinat Mangold nehmen"),
    ])
    func questionsContainingCommandWordsStayQuestions(spoken: String, question: String) {
        #expect(VoiceCommand.parse(spoken) == .question(question))
    }

    @Test(arguments: [
        ("Mir fehlt Feta", "feta"), ("Ich habe keine Kokosmilch", "kokosmilch"),
        ("Was kann ich statt Kokosmilch nehmen?", "kokosmilch"),
        ("Omni, Ersatz für frischen Ingwer", "frischen ingwer"),
        ("Hab keinen Spinat mehr", "spinat"),
    ])
    func recognisesSubstitutions(spoken: String, ingredient: String) {
        let addressed = spoken.hasPrefix("Omni")
        #expect(VoiceCommand.parse(spoken) == .substitute(ingredient: ingredient, addressed: addressed))
    }

    @Test func passesFreeQuestionsAfterTheWakeWord() {
        #expect(VoiceCommand.parse("Omni, kann ich das auch einfrieren?") == .question("kann ich das auch einfrieren"))
        #expect(VoiceCommand.parse("Kann ich das auch einfrieren?") == nil)
    }

    @Test func findsIngredientsByName() throws {
        let curry = try #require(try RecipeLibrary.bundled().first { $0.id == "kichererbsen-spinat-curry" })
        let session = CookingSession(recipe: curry)
        #expect(session.ingredient(named: "kokosmilch")?.id == "kokosmilch")
        #expect(session.ingredient(named: "ingwer")?.id == "ingwer")
        #expect(session.ingredient(named: "spinat")?.id == "spinat")
        #expect(session.ingredient(named: "frischen ingwer")?.id == "ingwer")
        #expect(session.ingredient(named: "noch kokosmilch")?.id == "kokosmilch")
        #expect(session.ingredient(named: "Feta") == nil)
        #expect(session.ingredient(named: "ahnung wann anderen kommen") == nil)
    }

    @Test func substitutesFollowTheChosenServings() throws {
        let salmon = try #require(try RecipeLibrary.bundled().first { $0.id == "ingwer-lachs-pak-choi" })
        let session = CookingSession(recipe: salmon, servings: 6)
        let lachs = try #require(session.ingredient(named: "Lachs"))
        let substitutions = session.substitutions(for: lachs)
        #expect(substitutions.map(\.substitute.name) == ["Kabeljaufilet", "Lachsforelle"])
        #expect(substitutions.first?.amount == .measured(6, .piece))
    }
}
