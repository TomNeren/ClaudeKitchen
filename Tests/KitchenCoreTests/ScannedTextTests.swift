import Testing

@testable import KitchenCore

@Suite("Scanned cookbook pages")
struct ScannedTextTests {
    static let recipePage = """
        Linsensuppe mit Kreuzkümmel
        Für 4 Personen
        200 g rote Linsen, 1 Zwiebel, 1 Möhre, 800 ml Gemüsebrühe, Salz und Pfeffer.
        Die Zwiebel schälen und fein würfeln, die Möhre in Scheiben schneiden. Alles mit den Linsen
        und der Brühe aufkochen und zwanzig Minuten leise köcheln lassen.
        """

    @Test func acceptsAReadableTextLayer() {
        #expect(ScannedText.isUsable(Self.recipePage))
    }

    @Test(arguments: [
        "",
        "  \n 127 \n",
        "Linsensuppe",
    ])
    func rejectsEmptyOrTinyLayers(_ text: String) {
        #expect(!ScannedText.isUsable(text))
    }

    @Test func rejectsBrokenFontEncodings() {
        let replaced = Self.recipePage.replacingOccurrences(of: "e", with: "\u{FFFD}")
        #expect(!ScannedText.isUsable(replaced))
        let privateUse = Self.recipePage.replacingOccurrences(of: "n", with: "\u{E001}")
        #expect(!ScannedText.isUsable(privateUse))
    }

    @Test func rejectsShiftedCharacterCodes() {
        // A font without a usable encoding often maps every letter one or more code points off.
        let shifted = String(
            String.UnicodeScalarView(
                Self.recipePage.unicodeScalars.map { scalar in
                    guard ("a"..."x").contains(scalar), let next = Unicode.Scalar(scalar.value + 1) else {
                        return scalar
                    }
                    return next
                }))
        #expect(!ScannedText.isUsable(shifted))
    }

    @Test func rejectsLettersSpacedApart() {
        let spaced = Self.recipePage.map { $0.isLetter ? "\($0) " : String($0) }.joined()
        #expect(!ScannedText.isUsable(spaced))
    }

    @Test func rejectsMostlySymbols() {
        let symbols = String(repeating: "Linsen ", count: 15) + String(repeating: "|#*/=~^ ", count: 40)
        #expect(!ScannedText.isUsable(symbols))
    }

    @Test func joinsWordsSplitAtALineEnd() {
        #expect(ScannedText.cleanedPage("Die Zwie-\nbeln schälen") == "Die Zwiebeln schälen")
        #expect(ScannedText.cleanedPage("Die Zwie¬\nbeln schälen") == "Die Zwiebeln schälen")
    }

    @Test func keepsHyphensThatBelong() {
        #expect(ScannedText.cleanedPage("Kartoffel-\nSalat") == "Kartoffel-Salat")
        #expect(ScannedText.cleanedPage("Zwiebel-\nund Knoblauchwürfel") == "Zwiebel- und Knoblauchwürfel")
        #expect(ScannedText.cleanedPage("Salz\n- 200 g Mehl") == "Salz\n- 200 g Mehl")
        #expect(ScannedText.cleanedPage("3-\n4 Minuten") == "3-\n4 Minuten")
    }

    @Test func spellsOutLigaturesAndDropsSoftHyphens() {
        #expect(ScannedText.cleanedPage("ﬂüssig, Kräuter ﬁn\u{00AD}den") == "flüssig, Kräuter finden")
    }

    @Test func collapsesWhitespaceAndJoinsPages() {
        let pages = ["  Linsen   suppe \r\n\n\n 200 g  Linsen ", "   ", "Seite\tzwei"]
        #expect(ScannedText.cleaned(pages: pages) == "Linsen suppe\n200 g Linsen\n\nSeite zwei")
    }

    @Test func cutsVeryLongScans() {
        let page = String(repeating: "Linsen ", count: 5_000)
        #expect(ScannedText.cleaned(pages: [page, page]).count == PlainText.maxCharacters)
    }
}

@Suite("PDF page selection")
struct PageSelectionTests {
    @Test func startsWithTheFirstPage() {
        #expect(PageSelection(pageCount: 12).pages == [0])
        #expect(PageSelection(pageCount: 0).pages.isEmpty)
        #expect(PageSelection(pageCount: -3).pageCount == 0)
    }

    @Test func togglesAndKeepsPagesInOrder() {
        var selection = PageSelection(pageCount: 12)
        selection.toggle(7)
        selection.toggle(3)
        #expect(selection.pages == [0, 3, 7])
        selection.toggle(0)
        #expect(selection.pages == [3, 7])
        #expect(selection.contains(7) && !selection.contains(0))
    }

    @Test func ignoresPagesOutsideTheDocument() {
        var selection = PageSelection(pageCount: 3)
        selection.toggle(3)
        selection.toggle(-1)
        #expect(selection.pages == [0])
    }

    @Test func stopsAtTheMaximum() {
        var selection = PageSelection(pageCount: 20)
        for page in 1...10 { selection.toggle(page) }
        #expect(selection.pages == [0, 1, 2, 3])
        #expect(selection.isFull)
        selection.toggle(2)
        selection.toggle(9)
        #expect(selection.pages == [0, 1, 3, 9])
    }
}
