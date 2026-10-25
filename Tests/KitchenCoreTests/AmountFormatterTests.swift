import Testing

@testable import KitchenCore

@Suite("Amount formatting")
struct AmountFormatterTests {
    @Test(arguments: [
        (Amount.measured(200, .gram), "200 g"),
        (.measured(666.67, .gram), "670 g"),
        (.measured(133.3, .gram), "135 g"),
        (.measured(13.4, .gram), "13 g"),
        (.measured(0.2, .gram), "1 g"),
        (.measured(1, .piece), "1 Stk"),
        (.measured(1.5, .piece), "1½ Stk"),
        (.measured(0.333, .piece), "¼ Stk"),
        (.measured(2.666, .clove), "2¾ Zehen"),
        (.measured(0.1, .teaspoon), "¼ TL"),
        (.measured(2, .tablespoon), "2 EL"),
        (.toTaste, "nach Geschmack"),
    ])
    func formatsGermanKitchenNotation(amount: Amount, expected: String) {
        #expect(AmountFormatter.string(for: amount) == expected)
    }
}
