/// German singular and plural for servings.
enum Portions {
    static func text(_ count: Int) -> String {
        count == 1 ? "1 Portion" : "\(count) Portionen"
    }
}
