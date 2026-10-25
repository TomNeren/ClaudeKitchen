import Foundation
import KitchenCore

/// Calls the Claude Messages API to turn recipe text into a draft. Request and response shapes live in KitchenCore.
struct ClaudeClient {
    enum ClientError: Error {
        case missingKey
        case network(String)
    }

    var session: URLSession = .shared

    func draft(for recipeText: String, profile: DeviceProfile = .omniCook) async throws -> RecipeDraft {
        guard let key = APIKeyStore.load() else { throw ClientError.missingKey }
        var request = URLRequest(url: ClaudeRecipeImport.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        for (name, value) in ClaudeRecipeImport.headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.httpBody = try ClaudeRecipeImport.requestBody(recipeText: recipeText, profile: profile)
        let data: Data
        do {
            (data, _) = try await session.data(for: request)
        } catch {
            throw ClientError.network(error.localizedDescription)
        }
        // Error statuses carry an error object, which `draft(fromResponse:)` reports with its type and message.
        return try ClaudeRecipeImport.draft(fromResponse: data)
    }

    /// Downloads a recipe page and reduces it to text.
    func pageText(at url: URL) async throws -> String {
        do {
            let (data, _) = try await session.data(from: url)
            return PlainText.fromHTML(String(decoding: data, as: UTF8.self))
        } catch {
            throw ClientError.network(error.localizedDescription)
        }
    }
}
