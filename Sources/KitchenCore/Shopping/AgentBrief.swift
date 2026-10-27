import Foundation

/// The shopping list as a German brief for a browser agent that fills the cart of an online supermarket the user
/// is logged into (PLAN.md, decision 39). Shop-neutral: the agent works in whatever shop is open.
///
/// The agent only fills the cart. Checkout, payment and account changes stay with the user, and the brief tells it
/// to stop at captchas or security checks instead of getting around them.
public enum AgentBrief {
    /// The brief for `items`. Items whose stock is unknown go into a section the agent only buys after asking.
    public static func text(for items: [ShoppingList.Item], catalog: FoodCatalog) -> String {
        let ask = items.filter { $0.reason == .unknownStock }
        let buy = items.filter { $0.reason != .unknownStock }
        var lines = [
            "Einkaufsauftrag",
            "",
            "Bitte lege diese Einkaufsliste in den Warenkorb des Online-Supermarkts, der in diesem Browser geöffnet "
                + "ist und in dem ich eingeloggt bin.",
            "",
            "Regeln:",
            "1. Lies zuerst die ganze Liste. Liegt schon etwas im Warenkorb, frag mich, ob es bleiben soll.",
            "2. Lege nur Artikel in den Warenkorb. Geh nicht zur Kasse, bestelle und bezahle nicht, und ändere keine "
                + "Konto-, Adress- oder Zahlungsdaten.",
            "3. Frag mich gleich am Anfang in einer einzigen Frage, welche Artikel unter „Erst fragen“ du einlegen "
                + "sollst. Wähle ich nichts aus, legst du keinen davon hinein.",
            "4. Suche mit dem angegebenen Suchbegriff. Nimm ein übliches Produkt und die kleinste Packung, die die "
                + "Menge deckt. Ist eine größere Packung billiger, nimm die billigere. Obst und Gemüse nach "
                + "Stückzahl, wenn der Shop das anbietet.",
            "5. Bei „1 Packung“ und „kleinste Packung“ reicht die kleinste Packung.",
            "6. Prüfe vor jedem Klick, dass der Button zum gewählten Produkt und zur richtigen Packungsgröße gehört. "
                + "Bei vielen Treffern such mit dem vollen Produktnamen, bis nur wenige übrig sind.",
            "7. Findest du nichts Passendes, leg nichts Falsches hinein. Such eine naheliegende Alternative (bei Fisch "
                + "und Fleisch ist Tiefkühlware in Ordnung) und schlag sie mir mit Menge und Preis vor. Hinein kommt "
                + "sie erst, wenn ich zustimme.",
            "8. Löse keine Captchas oder Sicherheitsabfragen. Erscheint eine, hör auf und sag mir Bescheid.",
            "9. Zum Schluss öffne den Warenkorb und gleiche ihn mit deiner Auswahl ab: jeder Artikel genau einmal, "
                + "richtige Größe, Summe stimmt. Dann eine Tabelle mit Artikel, gewähltem Produkt, Menge und Preis, "
                + "die Summe und alles, was gefehlt hat.",
        ]
        if !buy.isEmpty {
            lines += ["", "Einkaufen:"]
            lines += buy.map { line($0, catalog: catalog) }
        }
        if !ask.isEmpty {
            lines += ["", "Erst fragen (vielleicht noch zu Hause):"]
            lines += ask.map { line($0, catalog: catalog) }
        }
        return lines.joined(separator: "\n")
    }

    /// "- Tofu, fest: 400 g. Suchbegriff: Tofu natur"
    static func line(_ item: ShoppingList.Item, catalog: FoodCatalog) -> String {
        let term = item.food.flatMap { catalog.food($0) }?.searchTerm ?? item.name
        return "- \(item.name): \(quantity(item.quantity)). Suchbegriff: \(term)"
    }

    static func quantity(_ quantity: ShoppingList.Item.Quantity) -> String {
        switch quantity {
        case .grams(let grams, let pieces?):
            "\(pieces) Stk (etwa \(AmountFormatter.string(for: .measured(grams, .gram))))"
        case .grams(let grams, nil):
            "mindestens \(AmountFormatter.string(for: .measured(grams, .gram)))"
        case .level:
            "1 Packung"
        case .unknown:
            "kleinste Packung"
        }
    }
}
