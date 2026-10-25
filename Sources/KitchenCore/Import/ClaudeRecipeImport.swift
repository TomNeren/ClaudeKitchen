import Foundation

/// Builds the Claude Messages API request that turns a free-text recipe into a `Recipe`, and reads the answer.
/// Networking stays in the app; everything here is plain data and testable on Linux.
public enum ClaudeRecipeImport {
    public static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    public static let model = "claude-opus-5-5"
    public static let apiVersion = "2026-10-21"
    /// Server-side refusal fallback, `fallbacks: "default"`.
    public static let fallbackBeta = "server-side-fallback-2026-07-01"

    public enum ResponseError: Error, Equatable {
        /// The API answered with an error object, for example an invalid key or exhausted credit.
        case api(type: String, message: String)
        /// A non-success HTTP status without a readable error object, for example from a gateway.
        case http(status: Int)
        /// The model declined the request.
        case refusal
        /// The answer was cut off at `max_tokens`.
        case truncated
        /// No text block with the recipe JSON, or JSON that does not match the schema.
        case missingRecipe
    }

    /// HTTP headers besides the API key (`x-api-key`), which the app adds from the Keychain.
    public static let headers: [String: String] = [
        "content-type": "application/json",
        "anthropic-version": apiVersion,
        "anthropic-beta": fallbackBeta,
    ]

    /// Units the model may use: every `MeasureUnit` plus `ml`, which counts as grams.
    static let units = MeasureUnit.allCases.map(\.rawValue) + ["ml"]

    /// The JSON body for converting `recipeText`, with the limits of `profile` spelled out for the model.
    /// Key order is kept, so the schema lists properties in the order the model should fill them.
    public static func requestBody(recipeText: String, profile: DeviceProfile) throws -> Data {
        let body: JSONValue = .object([
            ("model", .string(model)),
            ("max_tokens", .integer(16_000)),
            ("fallbacks", .string("default")),
            ("system", .string(systemPrompt(for: profile))),
            (
                "output_config",
                .object([
                    ("effort", .string("low")),
                    ("format", .object([("type", .string("json_schema")), ("schema", schema)])),
                ])
            ),
            (
                "messages",
                .array([
                    .object([
                        ("role", .string("user")),
                        ("content", .string("Bereite dieses Rezept für den \(profile.name) auf:\n\n\(recipeText)")),
                    ])
                ])
            ),
        ])
        return try body.encoded()
    }

    /// Reads a Messages API response and turns the recipe JSON into a `Recipe` with id `id`.
    /// `status` is the HTTP status; a failure status without an error object becomes `.http`.
    public static func recipe(fromResponse data: Data, status: Int = 200, id: RecipeID) throws -> Recipe {
        try draft(fromResponse: data, status: status).recipe(id: id)
    }

    static func draft(fromResponse data: Data, status: Int = 200) throws -> RecipeDraft {
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
            throw (200..<300).contains(status) ? ResponseError.missingRecipe : ResponseError.http(status: status)
        }
        if let error = response.error {
            throw ResponseError.api(type: error.type, message: error.message)
        }
        guard (200..<300).contains(status) else { throw ResponseError.http(status: status) }
        switch response.stopReason {
        case "refusal":
            throw ResponseError.refusal
        case "max_tokens":
            throw ResponseError.truncated
        default:
            break
        }
        guard let text = response.content?.first(where: { $0.type == "text" })?.text,
            let draft = try? JSONDecoder().decode(RecipeDraft.self, from: Data(text.utf8))
        else {
            throw ResponseError.missingRecipe
        }
        return draft
    }

    /// What the model needs to know about the device. Every number comes from `profile`.
    public static func systemPrompt(for profile: DeviceProfile) -> String {
        let accessories = profile.ownedAccessories.map(\.rawValue).sorted().joined(separator: ", ")
        let fill = String(format: "%.1f", profile.maxFillLiters).replacingOccurrences(of: ".", with: ",")
        return """
            Du wandelst Rezepte in Schritt-für-Schritt-Anleitungen für den \(profile.name) um, einen Multikocher mit \
            Heizung, Messer und Waage. Antworte nur mit dem JSON nach Schema.

            Gerät:
            - Temperatur \(profile.temperatureRange.lowerBound) bis \(profile.temperatureRange.upperBound) °C, \
            in ganzen Grad.
            - Stufen vorwärts \(profile.forwardSpeeds.lowerBound) bis \(profile.forwardSpeeds.upperBound); \
            Linkslauf (reverse: true, Stufen \(profile.reverseSpeeds.lowerBound) bis \
            \(profile.reverseSpeeds.upperBound)) rührt sanft, ohne zu zerkleinern.
            - Laufzeit pro Schritt höchstens \(Int(profile.maxDuration / .seconds(60))) Minuten, in Sekunden angeben.
            - Topf bis \(fill) l Füllmarke.
            - Zubehör vorhanden: \(accessories). Dampfgaren nur mit program "steam", steam: true, ohne Stufe und \
            mit accessory "steamer".
            - Programme: \(Program.allCases.map(\.rawValue).joined(separator: ", ")).

            Regeln:
            - Mengen mit unit \(units.joined(separator: ", ")); Stückzahlen ohne passende Einheit als Stk; \
            "nach Geschmack" als quantity und unit null.
            - scales false für Zutaten, die bei mehr Portionen gleich bleiben (Lorbeerblatt, Wasser für den Dampf).
            - Pro Schritt eine Handlung. ingredientIndexes nennt die Zutaten, die in diesem Schritt hinzukommen, auch \
            in den Dampfaufsatz, als Positionen in der Liste ingredients, gezählt ab 0 (die erste Zutat ist 0).
            - freshPot true für einen Schritt, der in einem leeren, sauberen Topf neu beginnt, zum Beispiel eine \
            Beilage nach dem Hauptgericht.
            - setting nur, wenn am Gerät etwas einzustellen ist; Zerkleinern als kurzer Schritt mit hoher Stufe \
            und wenigen Sekunden, Andünsten mit Linkslauf.
            - Was das Gerät nicht kann (Backofen, Pfanne), als Schritt ohne setting mit Hinweis in note.
            - Texte auf Deutsch, kurz und im Imperativ. tag wie "Mediterran · Ofen" mit Mittelpunkt.
            """
    }

    private static func nullable(_ value: JSONValue) -> JSONValue {
        .object([("anyOf", .array([value, .object([("type", .string("null"))])]))])
    }

    private static func type(_ name: String) -> JSONValue {
        .object([("type", .string(name))])
    }

    private static func enumeration(_ values: [String]) -> JSONValue {
        .object([("type", .string("string")), ("enum", .array(values.map(JSONValue.string)))])
    }

    private static func array(of items: JSONValue) -> JSONValue {
        .object([("type", .string("array")), ("items", items)])
    }

    /// An object schema whose properties are all required, in the given order, with no extras.
    private static func object(_ properties: [(String, JSONValue)]) -> JSONValue {
        .object([
            ("type", .string("object")),
            ("properties", .object(properties)),
            ("required", .array(properties.map { .string($0.0) })),
            ("additionalProperties", .bool(false)),
        ])
    }

    /// JSON schema of the draft for structured outputs, in the order the model should write it.
    public static var schema: JSONValue {
        let setting = object([
            ("program", enumeration(Program.allCases.map(\.rawValue))),
            ("celsius", nullable(type("integer"))),
            ("steam", type("boolean")),
            ("speed", nullable(type("integer"))),
            ("reverse", type("boolean")),
            ("seconds", nullable(type("integer"))),
        ])
        let ingredient = object([
            ("name", type("string")),
            ("quantity", nullable(type("number"))),
            ("unit", nullable(enumeration(units))),
            ("note", nullable(type("string"))),
            ("scales", type("boolean")),
        ])
        let step = object([
            ("phase", type("string")),
            ("text", type("string")),
            ("note", nullable(type("string"))),
            ("ingredientIndexes", array(of: type("integer"))),
            ("setting", nullable(setting)),
            ("accessory", nullable(enumeration(Accessory.allCases.map(\.rawValue)))),
            ("freshPot", type("boolean")),
        ])
        return object([
            ("name", type("string")),
            ("tag", type("string")),
            ("baseServings", type("integer")),
            ("totalMinutes", type("integer")),
            ("ingredients", array(of: ingredient)),
            ("steps", array(of: step)),
        ])
    }

    private struct Response: Decodable {
        struct Block: Decodable {
            var type: String
            var text: String?
        }

        struct APIError: Decodable {
            var type: String
            var message: String
        }

        var content: [Block]?
        var stopReason: String?
        var error: APIError?

        enum CodingKeys: String, CodingKey {
            case content, error
            case stopReason = "stop_reason"
        }
    }
}
