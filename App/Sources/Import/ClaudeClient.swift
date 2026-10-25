import Foundation
import KitchenCore

/// Calls the Claude Messages API to turn recipe text into a recipe. Request and response shapes live in KitchenCore.
struct ClaudeClient {
    enum ClientError: Error {
        case missingKey
        case network(String)
        case page(status: Int)
        case insecureLink
    }

    var session: URLSession = .shared

    func recipe(for recipeText: String, id: RecipeID, profile: DeviceProfile = .omniCook) async throws -> Recipe {
        guard let key = APIKeyStore.load() else { throw ClientError.missingKey }
        var request = URLRequest(url: ClaudeRecipeImport.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        for (name, value) in ClaudeRecipeImport.headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.httpBody = try ClaudeRecipeImport.requestBody(recipeText: recipeText, profile: profile)
        let (data, response) = try await load(request)
        return try ClaudeRecipeImport.recipe(fromResponse: data, status: response.statusCode, id: id)
    }

    /// Downloads a recipe page over HTTPS and reduces it to text, decoding with the page's own charset.
    func pageText(at url: URL) async throws -> String {
        guard url.scheme == "https" else { throw ClientError.insecureLink }
        let (data, response) = try await load(URLRequest(url: url))
        guard (200..<300).contains(response.statusCode) else { throw ClientError.page(status: response.statusCode) }
        let encoding =
            response.textEncodingName
            .map { CFStringConvertIANACharSetNameToEncoding($0 as CFString) }
            .flatMap {
                $0 == kCFStringEncodingInvalidId
                    ? nil : String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding($0))
            }
            ?? .utf8
        let html = String(data: data, encoding: encoding) ?? String(decoding: data, as: UTF8.self)
        return PlainText.fromHTML(html)
    }

    private func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ClientError.network("Keine HTTP-Antwort") }
            return (data, http)
        } catch let error as ClientError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw ClientError.network(error.localizedDescription)
        }
    }
}
