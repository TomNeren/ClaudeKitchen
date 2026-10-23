import Testing
@testable import KitchenCore

@Suite("Amount scaling")
struct AmountTests {
    @Test(arguments: [
        (200.0, 3, 3, 200.0),
        (200.0, 3, 6, 400.0),
        (200.0, 3, 1, 200.0 / 3),
        (1.0, 3, 8, 8.0 / 3),
    ])
    func scalesMeasuredAmounts(value: Double, base: Int, servings: Int, expected: Double) {
        let scaled = Amount.measured(value, .gram).scaled(from: base, to: servings)
        guard case .measured(let result, .gram) = scaled else {
            Issue.record("Expected a measured amount in grams, got \(scaled)")
            return
        }
        #expect(abs(result - expected) < 0.0001)
    }

    @Test func toTasteDoesNotScale() {
        #expect(Amount.toTaste.scaled(from: 3, to: 6) == .toTaste)
    }
}
