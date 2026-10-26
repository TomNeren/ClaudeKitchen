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

    /// One line per item, "2 Stk (200 g) Zwiebel", for the share text and Reminders.
    static func line(_ item: ShoppingList.Item) -> String {
        "\(quantity(item.quantity)) \(item.name)"
    }

    /// The open items as plain text for the share sheet, grouped by aisle.
    static func plainText(_ open: [ShoppingList.Item]) -> String {
        var lines = ["Einkaufsliste"]
        for aisle in Aisle.allCases {
            let items = open.filter { $0.aisle == aisle }
            guard !items.isEmpty else { continue }
            lines.append("")
            lines.append(Self.aisle(aisle))
            lines += items.map { "- \(line($0))" }
        }
        return lines.joined(separator: "\n")
    }

    static func exported(_ count: Int) -> String {
        switch count {
        case 0: "Die Liste in Erinnerungen ist schon aktuell."
        case 1: "1 Eintrag in der Liste „\(RemindersExport.listTitle)“."
        default: "\(count) Einträge in der Liste „\(RemindersExport.listTitle)“."
        }
    }
}
