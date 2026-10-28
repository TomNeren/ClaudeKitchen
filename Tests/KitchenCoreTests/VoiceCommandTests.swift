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

@Suite("Voice commands in real transcripts")
struct VoiceTranscriptTests {
    @Test(arguments: [
        ("Nächsten Schritt", VoiceCommand.next), ("Okay, dann jetzt bitte weiter", .next), ("Erledigt", .next),
        ("Wie lange dauert es noch?", .remainingTime), ("Wann ist der Timer fertig?", .remainingTime),
        ("Starte Timer", .startTimer), ("Timer stoppen", .pauseTimer), ("Noch einmal bitte", .repeatStep),
        ("Was soll ich machen?", .repeatStep), ("Zurück zum vorherigen Schritt", .previous),
        ("Okay Omni, weiter", .next), ("Ommi, wie lange noch?", .remainingTime),
    ])
    func recognisesEverydayPhrasings(spoken: String, expected: VoiceCommand) {
        #expect(VoiceCommand.parse(spoken) == expected)
    }

    @Test func splitsSeveralSentencesInOneResult() {
        let parsed = VoiceCommand.parseSentences("Weiter. Wie lange noch? Und dann war sie einfach weg, stell dir vor.")
        #expect(
            parsed.map(\.sentence) == ["Weiter.", "Wie lange noch?", "Und dann war sie einfach weg, stell dir vor."])
        #expect(parsed.map(\.command) == [.next, .remainingTime, nil])
    }

    @Test func wakeWordAsItsOwnSentenceAddressesTheNext() {
        let parsed = VoiceCommand.parseSentences("Omni. Kann ich das einfrieren?")
        #expect(parsed.map(\.command) == [.question("Kann ich das einfrieren")])
        #expect(VoiceCommand.parseSentences("Omni.").map(\.command) == [nil])
    }

    @Test func keepsDecimalsInOneSentence() {
        #expect(VoiceCommand.sentences(in: "Nimm 2.5 Gramm. Weiter") == ["Nimm 2.5 Gramm.", "Weiter"])
    }

    @Test func fillerWordsDoNotTurnConversationIntoCommands() {
        #expect(VoiceCommand.parse("Und dann sind wir einfach weiter gefahren bis zum Strand") == nil)
        #expect(VoiceCommand.parse("Die nächste Zwiebel ist schon weich") == nil)
        #expect(VoiceCommand.parse("Omi hat gestern angerufen") == nil)
    }
}

@Suite("Spice questions by voice")
struct VoiceExplainTests {
    @Test(arguments: [
        ("Was ist Garam Masala?", "garam masala", false), ("Woraus besteht Khmeli Suneli?", "khmeli suneli", false),
        ("Was ist eigentlich Asafoetida", "asafoetida", false),
        ("Was steckt in Garam Masala drin?", "garam masala", false),
        ("Omni, was ist Galgant?", "galgant", true),
    ])
    func recognisesExplanationQuestions(spoken: String, ingredient: String, addressed: Bool) {
        #expect(VoiceCommand.parse(spoken) == .explain(ingredient: ingredient, addressed: addressed))
    }

    @Test func dropsTheWakeWordForTheModel() {
        #expect(VoiceCommand.withoutWakeWord("Okay Omni, was ist Ras el-Hanout?") == "was ist Ras el-Hanout")
        #expect(VoiceCommand.withoutWakeWord("Was ist Sumach?") == "Was ist Sumach")
    }

    @Test func keepsStepQuestionsAndConversationApart() {
        #expect(VoiceCommand.parse("Was ist der nächste Schritt?") == .next)
        #expect(VoiceCommand.parse("Was ist das?") == nil)
        #expect(VoiceCommand.parse("Was ist denn mit dir los, du bist heute so still beim Essen") == nil)
    }
}
