import CoreGraphics
import Foundation
import KitchenCore
import PDFKit
import Vision

/// Reads the text of chosen PDF pages for an import: the PDF's own text layer when it is usable, otherwise text
/// recognition with Vision on the rendered page, in German and English. Runs off the main actor.
struct PDFRecipeReader: Sendable {
    enum ReaderError: Error, Equatable {
        /// Not a PDF, damaged, or locked with a password.
        case unreadable
        /// Neither the text layer nor text recognition found any text on the chosen pages.
        case noText
    }

    struct Result: Sendable, Equatable {
        let text: String
        let source: ScannedText.Source
    }

    /// Longest side of the image handed to text recognition. Enough for cookbook body text without wasting memory.
    private static let recognitionSide: CGFloat = 3_000

    /// The text of `pages` (zero-based) in `data`. Each page is judged on its own, so a scan where only some pages
    /// carry a good text layer still uses it where it can; the result reports recognition if any page needed it.
    @concurrent
    func read(_ data: Data, pages: [Int]) async throws -> Result {
        guard let document = PDFDocument(data: data), !document.isLocked else { throw ReaderError.unreadable }
        var texts: [String] = []
        var recognized = false
        for index in pages {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { continue }
            let layer = page.string ?? ""
            if ScannedText.isUsable(layer) {
                texts.append(layer)
            } else if let image = Self.image(of: page) {
                texts.append(try await Self.recognizeText(in: image))
                recognized = true
            }
        }
        let text = ScannedText.cleaned(pages: texts)
        guard !text.isEmpty else { throw ReaderError.noText }
        return Result(text: text, source: recognized ? .recognition : .textLayer)
    }

    /// The page rendered as a bitmap, rotation applied, at a size that suits text recognition.
    private static func image(of page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .cropBox)
        let longest = max(bounds.width, bounds.height)
        guard longest > 0 else { return nil }
        let scale = min(4, recognitionSide / longest)
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        return page.thumbnail(of: size, for: .cropBox).cgImage
    }

    /// Document recognition keeps the reading order of columns and paragraphs, which matters for cookbook layouts
    /// with ingredients beside the method.
    private static func recognizeText(in image: CGImage) async throws -> String {
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.recognitionLanguages = [
            Locale.Language(identifier: "de-DE"), Locale.Language(identifier: "en-US"),
        ]
        request.textRecognitionOptions.useLanguageCorrection = true
        let observations = try await request.perform(on: image)
        return observations.map(\.document.text.transcript).joined(separator: "\n")
    }
}
