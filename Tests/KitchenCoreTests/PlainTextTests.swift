import Testing

@testable import KitchenCore

@Suite("Plain text from HTML")
struct PlainTextTests {
    @Test func keepsTheReadableTextOnly() {
        let html = """
            <html><head><title>x</title><style>p{color:red}</style></head>
            <body><script>var a = "<p>no</p>";</script>
            <h1>Linsen&shy;suppe</h1><p>200&nbsp;g rote Linsen &amp; 1 Zwiebel</p>
            <ul><li>Schritt 1: bei 100&deg;C köcheln</li><li>Gr&uuml;&szlig;e</li></ul></body></html>
            """
        #expect(
            PlainText.fromHTML(html)
                == "Linsen&shy;suppe\n200 g rote Linsen & 1 Zwiebel\nSchritt 1: bei 100°C köcheln\nGrüße")
    }

    @Test func cutsVeryLongPages() {
        let html = String(repeating: "<p>Tomate</p>", count: 10_000)
        #expect(PlainText.fromHTML(html).count == PlainText.maxCharacters)
    }
}
