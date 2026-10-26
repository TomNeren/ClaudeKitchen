import KitchenCore

/// German wording for the shopping screens and the shared list.
enum ShoppingText {
    static func aisle(_ aisle: Aisle) -> String {
        switch aisle {
        case .produce: "Obst und Gemüse"
        case .chilled: "Kühlung"
        case .frozen: "Tiefkühl"
        case .dryGoods: "Trockenware und Konserven"
        case .spices: "Gewürze und Saucen"
        case .other: "Sonstiges"
        }
    }

    static func quantity(_ quantity: ShoppingList.Item.Quantity) -> String {
        switch quantity {
        case .grams(let grams, let pieces?):
            "\(pieces) Stk (\(AmountFormatter.string(for: .measured(grams, .gram))))"
        case .grams(let grams, nil):
            AmountFormatter.string(for: .measured(grams, .gram))
        case .level:
            "1 Packung"
        case .unknown:
            "nach Bedarf"
        }
    }

    static func reason(_ reason: ShoppingList.Item.Reason) -> String? {
        switch reason {
        case .needed: nil
        case .belowMinimum: "Vorrat auffüllen"
        case .runningLow: "fast leer"
        case .unknownStock: "prüfen, ob noch da"
        }
    }

    static func level(_ level: SupplyLevel) -> String {
        switch level {
        case .available: "da"
        case .low: "fast leer"
        case .empty: "leer"
        }
    }

    /// The open items as plain text for the share sheet, grouped by aisle.
    static func plainText(_ list: ShoppingList, checked: Set<String>) -> String {
        let open = list.items.filter { !checked.contains($0.id) }
        var lines = ["Einkaufsliste"]
        for aisle in Aisle.allCases {
            let items = open.filter { $0.aisle == aisle }
            guard !items.isEmpty else { continue }
            lines.append("")
            lines.append(Self.aisle(aisle))
            lines += items.map { "- \(quantity($0.quantity)) \($0.name)" }
        }
        return lines.joined(separator: "\n")
    }
}
