import Foundation

/// What the cook said about a recipe in the cook log: the latest rating and every note, oldest first.
public struct RecipeFeedback: Sendable, Equatable {
    public struct Note: Sendable, Equatable {
        public var cookedAt: Date
        public var rating: Int?
        public var text: String

        public init(cookedAt: Date, rating: Int?, text: String) {
            self.cookedAt = cookedAt
            self.rating = rating
            self.text = text
        }
    }

    /// Ratings at or below this make a recipe worth improving even without a note.
    public static let lowRating = 3

    public var latestRating: Int?
    public var notes: [Note]

    public init(latestRating: Int?, notes: [Note]) {
        self.latestRating = latestRating
        self.notes = notes
    }

    public init(log: CookLog, recipe: RecipeID) {
        latestRating = log.latestRating(for: recipe)
        notes = log.entries(for: recipe)
            .sorted { $0.cookedAt < $1.cookedAt }
            .compactMap { entry in
                entry.note.map { Note(cookedAt: entry.cookedAt, rating: entry.rating, text: $0) }
            }
    }

    /// True when there is something to act on: a note, or a latest rating of 3 or less.
    public var isActionable: Bool {
        !notes.isEmpty || (latestRating.map { $0 <= Self.lowRating } ?? false)
    }

    /// The feedback as prompt lines, in German like the notes themselves.
    public var promptText: String {
        var lines: [String] = []
        if let latestRating {
            lines.append("Letzte Bewertung: \(latestRating) von 5 Sternen.")
        }
        if notes.isEmpty {
            lines.append("Keine Notizen.")
        } else {
            lines.append("Notizen nach dem Kochen, älteste zuerst:")
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            for note in notes {
                let stars = note.rating.map { ", \($0) Sterne" } ?? ""
                lines.append("- \(formatter.string(from: note.cookedAt))\(stars): \(note.text)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

/// An improved recipe from Claude, checked and ready to show for review.
public struct RecipeImprovement: Sendable, Equatable {
    public var recipe: Recipe
    /// Short German summary of what changed.
    public var summary: String
    /// Warnings from `DeviceProfile.validate`; errors never get this far.
    public var warnings: [ValidationIssue]
}

/// Builds the Claude Messages API request that improves a recipe from the cook's feedback, and checks the answer.
/// Networking stays in the app; everything here is plain data and testable on Linux.
public enum ClaudeRecipeImprovement {
    /// Why an answer was rejected. Transport and API errors come as `ClaudeRecipeImport.ResponseError`.
    public enum ImprovementError: Error, Equatable {
        case wrongID(expected: RecipeID, found: String)
        case wrongVariantOf(expected: RecipeID, found: String?)
        case markedVerified
        case emptySummary
        case duplicateIngredientID(String)
        case duplicateStepID(String)
        case draft(RecipeDraftError)
        case deviceIssues([ValidationIssue])
        case unusedIngredients([IngredientID])
        case catalogIssues([CatalogIssue])
    }

    /// The id for the next variant of `original`: `<original>-v<n>` with the smallest free `n`, starting at 1.
    public static func variantID(for original: RecipeID, taken: Set<RecipeID>) -> RecipeID {
        var number = 1
        while taken.contains(RecipeID("\(original.rawValue)-v\(number)")) {
            number += 1
        }
        return RecipeID("\(original.rawValue)-v\(number)")
    }

    /// The JSON body asking for an improved `recipe` with id `variantID`, given `feedback`.
    public static func requestBody(
        recipe: Recipe, feedback: RecipeFeedback, variantID: RecipeID, profile: DeviceProfile
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let recipeJSON = String(decoding: try encoder.encode(recipe), as: UTF8.self)
        let message = """
            Rezept (id \(recipe.id.rawValue)):
            \(recipeJSON)

            Rückmeldung nach dem Kochen:
            \(feedback.promptText)

            Gib die verbesserte Fassung mit id "\(variantID.rawValue)" und variantOf "\(recipe.id.rawValue)" zurück.
            """
        let body: JSONValue = .object([
            ("model", .string(ClaudeRecipeImport.model)),
            ("max_tokens", .integer(16_000)),
            ("fallbacks", .string("default")),
            ("system", .string(systemPrompt(for: profile))),
            (
                "output_config",
                .object([
                    ("effort", .string("medium")),
                    ("format", .object([("type", .string("json_schema")), ("schema", schema)])),
                ])
            ),
            ("messages", .array([.object([("role", .string("user")), ("content", .string(message))])])),
        ])
        return try body.encoded()
    }

    /// The rules for the model. Every device number comes from `profile`.
    public static func systemPrompt(for profile: DeviceProfile) -> String {
        """
        Du verbesserst ein Rezept für den \(profile.name), einen Multikocher mit Heizung, Messer und Waage, \
        anhand der Rückmeldung des Kochs. Antworte nur mit dem JSON nach Schema.

        \(ClaudeRecipeImport.deviceSection(for: profile))

        Regeln:
        - Ändere nur, was die Rückmeldung verlangt. Alles andere bleibt Wort für Wort und Wert für Wert gleich.
        - Unveränderte Zutaten und Schritte behalten ihre id aus dem Rezept. Geänderte Zutaten und Schritte \
        behalten ihre id ebenfalls; nur neue bekommen id null.
        - Bleib in den Grenzen des Geräts. Passt ein Wunsch nicht dazu, setz ihn so nah wie möglich um und \
        sag es in summary.
        - Verwende nur gewöhnliche Lebensmittel mit eindeutigem deutschem Namen, wie sie in den Zutaten \
        stehen, damit die App sie im Lebensmittelkatalog findet. Keine Markennamen, keine Fantasienamen.
        - Jede Zutat kommt in mindestens einem Schritt vor. ingredientIndexes nennt die Zutaten, die in \
        diesem Schritt hinzukommen, als Positionen in deiner Liste ingredients, gezählt ab 0.
        - Mengen mit unit \(ClaudeRecipeImport.units.joined(separator: ", ")); "nach Geschmack" als \
        quantity und unit null.
        - Gib das vollständige Rezept zurück, mit der vorgegebenen id, variantOf gleich der id des \
        Originals und verified false.
        - summary: zwei bis vier kurze deutsche Sätze, was du geändert hast und warum. Keine Gedankenstriche.
        - Texte auf Deutsch, kurz und im Imperativ.
        """
    }

    /// JSON schema of the answer: the import draft plus ids, `variantOf`, `verified` and `summary`.
    public static var schema: JSONValue {
        typealias Import = ClaudeRecipeImport
        let id = Import.nullable(Import.type("string"))
        let setting = Import.object([
            ("program", Import.enumeration(Program.allCases.map(\.rawValue))),
            ("celsius", Import.nullable(Import.type("integer"))),
            ("steam", Import.type("boolean")),
            ("speed", Import.nullable(Import.type("integer"))),
            ("reverse", Import.type("boolean")),
            ("seconds", Import.nullable(Import.type("integer"))),
        ])
        let ingredient = Import.object([
            ("id", id),
            ("name", Import.type("string")),
            ("quantity", Import.nullable(Import.type("number"))),
            ("unit", Import.nullable(Import.enumeration(Import.units))),
            ("note", Import.nullable(Import.type("string"))),
            ("scales", Import.type("boolean")),
        ])
        let step = Import.object([
            ("id", id),
            ("phase", Import.type("string")),
            ("text", Import.type("string")),
            ("note", Import.nullable(Import.type("string"))),
            ("ingredientIndexes", Import.array(of: Import.type("integer"))),
            ("setting", Import.nullable(setting)),
            ("accessory", Import.nullable(Import.enumeration(Accessory.allCases.map(\.rawValue)))),
            ("freshPot", Import.type("boolean")),
        ])
        return Import.object([
            ("summary", Import.type("string")),
            ("id", Import.type("string")),
            ("variantOf", Import.type("string")),
            ("verified", Import.type("boolean")),
            ("name", Import.type("string")),
            ("tag", Import.type("string")),
            ("baseServings", Import.type("integer")),
            ("totalMinutes", Import.type("integer")),
            ("ingredients", Import.array(of: ingredient)),
            ("steps", Import.array(of: step)),
        ])
    }

    /// Reads the answer and runs the full check chain: shape, ids, `variantOf`, device validation, every ingredient
    /// used, every ingredient mapped in `catalog`. Throws on the first failing stage; warnings come back for review.
    public static func improvement(
        fromResponse data: Data, status: Int = 200, original: Recipe, variantID: RecipeID, profile: DeviceProfile,
        catalog: FoodCatalog? = FoodCatalog.shared
    ) throws -> RecipeImprovement {
        let text = try ClaudeRecipeImport.text(fromResponse: data, status: status)
        guard let answer = try? JSONDecoder().decode(Answer.self, from: Data(text.utf8)) else {
            throw ClaudeRecipeImport.ResponseError.missingRecipe
        }
        guard answer.id == variantID.rawValue else {
            throw ImprovementError.wrongID(expected: variantID, found: answer.id)
        }
        guard answer.variantOf == original.id.rawValue else {
            throw ImprovementError.wrongVariantOf(expected: original.id, found: answer.variantOf)
        }
        guard answer.verified != true else { throw ImprovementError.markedVerified }
        let summary = answer.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else { throw ImprovementError.emptySummary }

        var recipe = try answer.recipe(variantID: variantID, original: original)
        if let catalog {
            recipe = recipe.assigningFoods(from: catalog, comparedTo: original)
        }

        let issues = profile.validate(recipe, catalog: catalog)
        let errors = issues.filter { $0.severity == .error }
        guard errors.isEmpty else { throw ImprovementError.deviceIssues(errors) }

        let used = Set(recipe.steps.flatMap(\.ingredientIDs))
        let unused = recipe.ingredients.map(\.id).filter { !used.contains($0) }
        guard unused.isEmpty else { throw ImprovementError.unusedIngredients(unused) }

        if let catalog {
            let catalogIssues = catalog.issues(in: recipe)
            guard catalogIssues.isEmpty else { throw ImprovementError.catalogIssues(catalogIssues) }
        }
        return RecipeImprovement(recipe: recipe, summary: summary, warnings: issues)
    }

    /// The answer as the schema describes it. `variantOf` and `verified` are optional here, so a missing value
    /// becomes a typed error instead of a decoding failure.
    struct Answer: Decodable {
        struct Ingredient: Decodable {
            var id: String?
            var name: String
            var quantity: Double?
            var unit: String?
            var note: String?
            var scales: Bool
        }

        struct Step: Decodable {
            var id: String?
            var phase: String
            var text: String
            var note: String?
            var ingredientIndexes: [Int]
            var setting: RecipeDraft.Setting?
            var accessory: String?
            var freshPot: Bool
        }

        var summary: String
        var id: String
        var variantOf: String?
        var verified: Bool?
        var name: String
        var tag: String
        var baseServings: Int
        var totalMinutes: Int
        var ingredients: [Ingredient]
        var steps: [Step]

        /// Converts through `RecipeDraft`, then puts back the ids the model kept. Kept ingredients also keep what
        /// the answer cannot carry: food, substitutes, `eaten`. New ones get fresh ids that clash with nothing.
        func recipe(variantID: RecipeID, original: Recipe) throws -> Recipe {
            let draft = RecipeDraft(
                name: name, tag: tag, baseServings: baseServings, totalMinutes: totalMinutes,
                ingredients: ingredients.map {
                    .init(name: $0.name, quantity: $0.quantity, unit: $0.unit, note: $0.note, scales: $0.scales)
                },
                steps: steps.map {
                    .init(
                        phase: $0.phase, text: $0.text, note: $0.note, ingredientIndexes: $0.ingredientIndexes,
                        setting: $0.setting, accessory: $0.accessory, freshPot: $0.freshPot)
                })
            let converted: Recipe
            do {
                converted = try draft.recipe(id: variantID)
            } catch let error as RecipeDraftError {
                throw ImprovementError.draft(error)
            }

            let ingredientIDs = try Self.ids(
                ingredients.map(\.id), generated: converted.ingredients.map(\.id.rawValue),
                duplicate: ImprovementError.duplicateIngredientID)
            let stepIDs = try Self.ids(
                steps.map(\.id), generated: converted.steps.map(\.id.rawValue),
                duplicate: ImprovementError.duplicateStepID)
            let rename = Dictionary(
                uniqueKeysWithValues: zip(converted.ingredients.map(\.id), ingredientIDs.map { IngredientID($0) }))

            var recipe = converted
            recipe.ingredients = zip(converted.ingredients, ingredientIDs).map { ingredient, rawID in
                let id = IngredientID(rawID)
                let kept = original.ingredient(id)
                return KitchenCore.Ingredient(
                    id: id, name: ingredient.name, amount: ingredient.amount,
                    food: kept?.food, note: ingredient.note,
                    scales: ingredient.scales, eaten: kept?.eaten ?? true, substitutes: kept?.substitutes ?? [],
                    foodChosenByHand: kept?.foodChosenByHand ?? false)
            }
            recipe.steps = zip(converted.steps, stepIDs).map { step, rawID in
                KitchenCore.Step(
                    id: StepID(rawID), phase: step.phase, text: step.text, note: step.note,
                    ingredientIDs: step.ingredientIDs.compactMap { rename[$0] }, setting: step.setting,
                    accessory: step.accessory, freshPot: step.freshPot)
            }
            recipe.variantOf = original.id
            recipe.verified = false
            recipe.origin = original.origin
            recipe.references = original.references
            recipe.authenticityChecks = original.authenticityChecks
            return recipe
        }

        /// Ids the model gave, with fresh ones for nil, made unique against both.
        private static func ids(
            _ given: [String?], generated: [String], duplicate: (String) -> ImprovementError
        ) throws -> [String] {
            var taken = Set(given.compactMap { $0 })
            var seen: Set<String> = []
            for case let id? in given where !seen.insert(id).inserted {
                throw duplicate(id)
            }
            return zip(given, generated).map { id, fallback in
                if let id { return id }
                return Slug.unique(fallback, fallback: "neu", taken: &taken)
            }
        }
    }
}

/// One difference between a recipe and its improved variant, matched by id.
public enum VariantChange: Sendable, Equatable {
    case ingredientAdded(Ingredient)
    case ingredientRemoved(Ingredient)
    case ingredientChanged(old: Ingredient, new: Ingredient)
    case stepAdded(Step)
    case stepRemoved(Step)
    case stepChanged(old: Step, new: Step)
}

extension RecipeImprovement {
    /// What differs from `original`: ingredients first, then steps, each in recipe order, removals last.
    public func changes(from original: Recipe) -> [VariantChange] {
        var changes: [VariantChange] = []
        for ingredient in recipe.ingredients {
            if let old = original.ingredient(ingredient.id) {
                if old.name != ingredient.name || old.amount != ingredient.amount || old.note != ingredient.note {
                    changes.append(.ingredientChanged(old: old, new: ingredient))
                }
            } else {
                changes.append(.ingredientAdded(ingredient))
            }
        }
        let newIngredients = Set(recipe.ingredients.map(\.id))
        changes += original.ingredients.filter { !newIngredients.contains($0.id) }.map(VariantChange.ingredientRemoved)
        let oldSteps = Dictionary(original.steps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for step in recipe.steps {
            if let old = oldSteps[step.id] {
                if old != step { changes.append(.stepChanged(old: old, new: step)) }
            } else {
                changes.append(.stepAdded(step))
            }
        }
        let newSteps = Set(recipe.steps.map(\.id))
        changes += original.steps.filter { !newSteps.contains($0.id) }.map(VariantChange.stepRemoved)
        return changes
    }
}
