import Testing

@testable import KitchenCore

@Suite("Ingredient lines")
struct IngredientLineTests {
    @Test(arguments: [
        ("200 g Rote Linsen", IngredientLine(name: "Rote Linsen", amount: .measured(200, .gram))),
        ("200g Feta", IngredientLine(name: "Feta", amount: .measured(200, .gram))),
        ("1,5 kg Kartoffeln", IngredientLine(name: "Kartoffeln", amount: .measured(1500, .gram))),
        ("100 ml Sahne", IngredientLine(name: "Sahne", amount: .measured(100, .gram))),
        ("0.5 l Gemüsebrühe", IngredientLine(name: "Gemüsebrühe", amount: .measured(500, .gram))),
        ("½ TL Kurkuma", IngredientLine(name: "Kurkuma", amount: .measured(0.5, .teaspoon))),
        ("1½ EL Olivenöl", IngredientLine(name: "Olivenöl", amount: .measured(1.5, .tablespoon))),
        ("1/2 TL Salz", IngredientLine(name: "Salz", amount: .measured(0.5, .teaspoon))),
        ("2 Zehen Knoblauch", IngredientLine(name: "Knoblauch", amount: .measured(2, .clove))),
        ("1 Zwiebel", IngredientLine(name: "Zwiebel", amount: .measured(1, .piece))),
        ("3 Eier (Größe M)", IngredientLine(name: "Eier", amount: .measured(3, .piece), note: "Größe M")),
        ("- 1 Dose Kichererbsen", IngredientLine(name: "Dose Kichererbsen", amount: .measured(1, .piece))),
        ("Salz", IngredientLine(name: "Salz", amount: .toTaste)),
        ("Prise Muskat", IngredientLine(name: "Muskat", amount: .toTaste)),
        ("nach Geschmack Pfeffer", IngredientLine(name: "Pfeffer", amount: .toTaste)),
        ("1 Prise Salz", IngredientLine(name: "Salz", amount: .toTaste)),
        ("1 Msp. Muskat", IngredientLine(name: "Muskat", amount: .toTaste)),
        ("1 ½ TL Kurkuma", IngredientLine(name: "Kurkuma", amount: .measured(1.5, .teaspoon))),
        ("1 1/2 EL Öl", IngredientLine(name: "Öl", amount: .measured(1.5, .tablespoon))),
        ("1.000 g Mehl", IngredientLine(name: "Mehl", amount: .measured(1000, .gram))),
        ("1. 200 g Mehl", IngredientLine(name: "Mehl", amount: .measured(200, .gram))),
        ("2) 1 Zwiebel", IngredientLine(name: "Zwiebel", amount: .measured(1, .piece))),
    ])
    func readsCommonNotations(line: String, expected: IngredientLine) {
        #expect(IngredientLine.parse(line) == expected)
    }

    @Test func skipsLinesWithoutAName() {
        #expect(IngredientLine.parse("") == nil)
        #expect(IngredientLine.parse("200 g") == nil)
        #expect(IngredientLine.parseList("200 g Linsen\n\n  \n1 Zwiebel").map(\.name) == ["Linsen", "Zwiebel"])
    }
}
