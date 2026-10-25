import Foundation

/// Builds the Claude Messages API request that turns a free-text recipe into a `RecipeDraft`, and reads the answer.
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
        /// The model declined the request.
        case refusal
        /// The answer was cut off at `max_tokens`.
        case truncated
        /// No text block with the recipe JSON.
        case missingRecipe
    }

    /// HTTP headers besides the API key (`x-api-key`), which the app adds from the Keychain.
    public static let headers: [String: String] = [
        "content-type": "application/json",
        "anthropic-version": apiVersion,
        "anthropic-beta": fallbackBeta,
    ]

    /// The JSON body for converting `recipeText`, with the limits of `profile` spelled out for the model.
    public static func requestBody(recipeText: String, profile: DeviceProfile) throws -> Data {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 16_000,
            "fallbacks": "default",
            "system": systemPrompt(for: profile),
            "output_config": [
                "effort": "low",
                "format": ["type": "json_schema", "schema": schema],
            ],
            "messages": [
                ["role": "user", "content": "Bereite dieses Rezept für den \(profile.name) auf:\n\n\(recipeText)"]
            ],
        ]
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    /// Reads a Messages API response body: the error object, a refusal, a truncation, or the recipe JSON.
    public static func draft(fromResponse data: Data) throws -> RecipeDraft {
        let response = try JSONDecoder().decode(Response.self, from: data)
        if let error = response.error {
            throw ResponseError.api(type: error.type, message: error.message)
        }
        switch response.stopReason {
        case "refusal":
            throw ResponseError.refusal
        case "max_tokens":
            throw ResponseError.truncated
        default:
            break
        }
        guard let text = response.content?.first(where: { $0.type == "text" })?.text else {
            throw ResponseError.missingRecipe
        }
        return try JSONDecoder().decode(RecipeDraft.self, from: Data(text.utf8))
    }

    /// What the model needs to know about the device. Every number comes from `profile`.
    public static func systemPrompt(for profile: DeviceProfile) -> String {
        let accessories = profile.ownedAccessories.map(\.rawValue).sorted().joined(separator: ", ")
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
            - Topf bis \(String(format: "%.1f", profile.maxFillLiters).replacingOccurrences(of: ".", with: ",")) l Füllmarke.
            - Zubehör vorhanden: \(accessories). Dampfgaren nur mit program "steam", steam: true, ohne Stufe und \
            mit accessory "steamer".
            - Programme: manual, steam, knead, sousVide, yogurt, weigh.

            Regeln:
            - Mengen in g, ml, Stk, Zehen, TL oder EL; "nach Geschmack" als quantity und unit null.
            - scales false für Zutaten, die bei mehr Portionen gleich bleiben (Lorbeerblatt, Wasser für den Dampf).
            - Pro Schritt eine Handlung. ingredientIndexes nennt, was in diesem Schritt in den Topf kommt.
            - setting nur, wenn am Gerät etwas einzustellen ist; Zerkleinern als kurzer Schritt mit hoher Stufe \
            und wenigen Sekunden, Andünsten mit Linkslauf.
            - Was das Gerät nicht kann (Backofen, Pfanne), als Schritt ohne setting mit Hinweis in note.
            - Texte auf Deutsch, kurz und im Imperativ. tag wie "Mediterran · Ofen" mit Mittelpunkt.
            """
    }

    private static func nullable(_ type: String) -> [String: Any] {
        ["anyOf": [["type": type], ["type": "null"]]]
    }

    private static func object(_ properties: [String: Any]) -> [String: Any] {
        [
            "type": "object", "properties": properties, "required": properties.keys.sorted(),
            "additionalProperties": false,
        ]
    }

    /// JSON schema of `RecipeDraft` for structured outputs.
    public static var schema: [String: Any] {
        let setting = object([
            "program": ["type": "string", "enum": Program.allCases.map(\.rawValue)],
            "celsius": nullable("integer"),
            "steam": ["type": "boolean"],
            "speed": nullable("integer"),
            "reverse": ["type": "boolean"],
            "seconds": nullable("integer"),
        ])
        let ingredient = object([
            "name": ["type": "string"],
            "quantity": nullable("number"),
            "unit": [
                "anyOf": [["type": "string", "enum": ["g", "ml", "Stk", "Zehen", "TL", "EL"]], ["type": "null"]]
            ],
            "note": nullable("string"),
            "scales": ["type": "boolean"],
        ])
        let step = object([
            "phase": ["type": "string"],
            "text": ["type": "string"],
            "note": nullable("string"),
            "ingredientIndexes": ["type": "array", "items": ["type": "integer"]],
            "setting": ["anyOf": [setting, ["type": "null"]]],
            "accessory": [
                "anyOf": [["type": "string", "enum": Accessory.allCases.map(\.rawValue)], ["type": "null"]]
            ],
        ])
        return object([
            "name": ["type": "string"],
            "tag": ["type": "string"],
            "baseServings": ["type": "integer"],
            "totalMinutes": ["type": "integer"],
            "ingredients": ["type": "array", "items": ingredient],
            "steps": ["type": "array", "items": step],
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
