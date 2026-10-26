import Foundation

/// Folds text for matching typed or imported words against names: case, diacritics, and letters without a base
/// letter.
enum TextFold {
    /// Letters that diacritic folding leaves alone because they have no base letter to decompose into.
    private static let extraFolds: [(String, String)] = [
        ("ı", "i"), ("ł", "l"), ("đ", "d"), ("ø", "o"), ("æ", "ae"), ("œ", "oe"), ("ß", "ss"),
    ]

    static func fold(_ text: String) -> String {
        extraFolds.reduce(text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)) {
            $0.replacing($1.0, with: $1.1)
        }
    }

    /// The folded words of `text`, split at everything that is not a letter or digit.
    static func words(_ text: String) -> [Substring] {
        fold(text).split { !$0.isLetter && !$0.isNumber }
    }
}
