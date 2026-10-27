import Foundation
import Testing

@testable import KitchenCore

/// The bar every bundled recipe has to meet, set by the first 30 (PLAN.md, section 3c). New recipes from
/// `Prompts/rezepte-erweitern.md` mirror these checks in their self-check list.
@Suite("Bundled recipe quality")
struct RecipeQualityTests {
    /// Step count of the first 30 recipes is 4 to 9; one step of headroom on top.
    static let stepCount = 4...10
    /// Step text of the first 30 recipes is 23 to 143 characters; a little headroom on both ends.
    static let stepTextLength = 20...160
    /// Step notes of the first 30 recipes reach 189 characters.
    static let maxNoteLength = 200
    /// Separator between the parts of a tag, for example "Indisch · Dal".
    static let tagSeparator = " · "

    /// First part of a tag, with the cuisine it belongs to and the country it names, if it names exactly one.
    /// Extend this table when a recipe needs a new adjective.
    static let tagAdjectives: [String: (cuisine: Cuisine, country: String?)] = [
        "Indisch": (.india, "Indien"),
        "Thailändisch": (.thailand, "Thailand"),
        "Vietnamesisch": (.southeastAsia, "Vietnam"),
        "Indonesisch": (.southeastAsia, "Indonesien"),
        "Malaysisch": (.southeastAsia, "Malaysia"),
        "Philippinisch": (.southeastAsia, "Philippinen"),
        "Chinesisch": (.china, "China"),
        "Japanisch": (.japanKorea, "Japan"),
        "Koreanisch": (.japanKorea, "Korea"),
        "Türkisch": (.turkeyLevant, "Türkei"),
        "Levantinisch": (.turkeyLevant, nil),
        "Libanesisch": (.turkeyLevant, "Libanon"),
        "Syrisch": (.turkeyLevant, "Syrien"),
        "Palästinensisch": (.turkeyLevant, "Palästina"),
        "Jordanisch": (.turkeyLevant, "Jordanien"),
        "Georgisch": (.georgia, "Georgien"),
        "Mediterran": (.europe, nil),
        "Osteuropäisch": (.europe, nil),
        "Griechisch": (.europe, "Griechenland"),
        "Italienisch": (.europe, "Italien"),
        "Spanisch": (.europe, "Spanien"),
        "Portugiesisch": (.europe, "Portugal"),
        "Französisch": (.europe, "Frankreich"),
        "Kroatisch": (.europe, "Kroatien"),
        "Ukrainisch": (.europe, "Ukraine"),
        "Polnisch": (.europe, "Polen"),
        "Ungarisch": (.europe, "Ungarn"),
        "Rumänisch": (.europe, "Rumänien"),
        "Bulgarisch": (.europe, "Bulgarien"),
        "Mexikanisch": (.mexicoPeru, "Mexiko"),
        "Peruanisch": (.mexicoPeru, "Peru"),
    ]

    /// The cook's own recipes, not traditional dishes (`Recipe.origin` is nil for them). They skip the origin,
    /// reference and authenticity checks and must not wear a cuisine in their tag; every other check applies.
    /// Generated recipes never go here.
    static let ownCreations: Set<RecipeID> = ["ingwer-lachs-pak-choi"]

    static let recipes: [Recipe] = (try? RecipeLibrary.bundled()) ?? []

    @Test func recipesLoad() {
        #expect(!Self.recipes.isEmpty)
    }

    @Test func everyTraditionalRecipeHasOriginReferencesAndChecks() {
        for recipe in Self.recipes where !Self.ownCreations.contains(recipe.id) {
            #expect(recipe.origin != nil, "\(recipe.id): no origin")
            let region = recipe.origin?.region ?? ""
            #expect(!region.isEmpty, "\(recipe.id): no region")
            #expect(!recipe.references.isEmpty, "\(recipe.id): no references")
            for reference in recipe.references {
                #expect(!reference.title.isEmpty, "\(recipe.id): reference without title")
                #expect(reference.author != nil || reference.url != nil, "\(recipe.id): \(reference.title)")
                if let year = reference.year {
                    #expect((1800...2026).contains(year), "\(recipe.id): \(reference.title) \(year)")
                }
            }
            #expect(recipe.authenticityChecks.count >= 2, "\(recipe.id): fewer than two authenticity checks")
            for check in recipe.authenticityChecks {
                #expect(!check.trimmingCharacters(in: .whitespaces).isEmpty, "\(recipe.id): empty check")
            }
        }
    }

    @Test func bundledRecipesAreNotVerified() {
        for recipe in Self.recipes {
            #expect(!recipe.verified, "\(recipe.id): only the cook marks a recipe as verified on the device")
        }
    }

    @Test func noDashesInUserFacingText() {
        for recipe in Self.recipes {
            for text in Self.userFacingTexts(of: recipe) {
                #expect(!text.contains("\u{2014}") && !text.contains("\u{2013}"), "\(recipe.id): \(text)")
                #expect(!text.contains(" - "), "\(recipe.id): hyphen used as a dash: \(text)")
            }
        }
    }

    @Test func stepCountAndLengthStayInRange() {
        for recipe in Self.recipes {
            #expect(Self.stepCount.contains(recipe.steps.count), "\(recipe.id): \(recipe.steps.count) steps")
            for step in recipe.steps {
                #expect(Self.stepTextLength.contains(step.text.count), "\(recipe.id)/\(step.id): \(step.text.count)")
                #expect((step.note?.count ?? 0) <= Self.maxNoteLength, "\(recipe.id)/\(step.id): note too long")
                #expect(!step.phase.isEmpty && !step.phase.contains(" · "), "\(recipe.id)/\(step.id): phase")
            }
        }
    }

    @Test func tagNamesTheCuisineOfTheOrigin() throws {
        for recipe in Self.recipes {
            let parts = recipe.tag.components(separatedBy: Self.tagSeparator)
            #expect((2...3).contains(parts.count), "\(recipe.id): tag \"\(recipe.tag)\"")
            for part in parts {
                #expect(!part.isEmpty && part == part.trimmingCharacters(in: .whitespaces), "\(recipe.id): tag part")
            }
            if Self.ownCreations.contains(recipe.id) {
                #expect(Self.tagAdjectives[parts[0]] == nil, "\(recipe.id): own creation tagged as a cuisine")
                continue
            }
            let adjective = try #require(
                Self.tagAdjectives[parts[0]], "\(recipe.id): unknown cuisine \"\(parts[0])\" in tag")
            #expect(adjective.cuisine == recipe.origin?.cuisine, "\(recipe.id): tag and origin disagree")
        }
    }

    @Test func ownCreationsExistAndClaimNoOrigin() {
        for id in Self.ownCreations {
            guard let recipe = Self.recipes.first(where: { $0.id == id }) else {
                Issue.record("\(id) is listed as an own creation but not bundled")
                continue
            }
            #expect(recipe.origin == nil, "\(id): an own creation has no origin")
            #expect(recipe.references.isEmpty && recipe.authenticityChecks.isEmpty, "\(id): nothing to cite or check")
        }
    }

    @Test func regionFitsTheCuisineAndTag() {
        let countries = Dictionary(
            Self.tagAdjectives.values.compactMap { entry in entry.country.map { ($0, entry.cuisine) } },
            uniquingKeysWith: { first, _ in first })
        for recipe in Self.recipes {
            guard let origin = recipe.origin, let region = origin.region else { continue }
            if let cuisine = countries[region] {
                #expect(cuisine == origin.cuisine, "\(recipe.id): \(region) is not in \(origin.cuisine)")
            }
            let adjective = recipe.tag.components(separatedBy: Self.tagSeparator).first ?? ""
            if let named = Self.tagAdjectives[adjective]?.country, countries[region] != nil {
                #expect(region == named, "\(recipe.id): tag says \(named), region says \(region)")
            }
        }
    }

    @Test func sameRegionIsSpelledTheSameEverywhere() {
        var spellings: [String: Set<String>] = [:]
        for recipe in Self.recipes {
            guard let region = recipe.origin?.region else { continue }
            spellings[Self.normalized(region), default: []].insert(region)
        }
        for (key, variants) in spellings {
            #expect(variants.count == 1, "\(key): \(variants.sorted())")
        }
    }

    @Test func noDishIsBundledTwice() {
        var seen: [String: RecipeID] = [:]
        for recipe in Self.recipes {
            let key = Self.normalized(Self.withoutParentheses(recipe.name))
            if let other = seen[key] {
                Issue.record("\(recipe.id) and \(other) are the same dish")
            }
            seen[key] = recipe.id
        }
    }

    @Test func normalisationFoldsSpellingVariants() {
        #expect(Self.normalized("Gà Kho Gừng") == Self.normalized("ga-kho gung"))
        #expect(Self.normalized(Self.withoutParentheses("Tomaten-Rührei (Fan Qie Chao Dan)")) == "tomatenruhrei")
        #expect(Self.normalized("Nordindien") != Self.normalized("Süd-Indien"))
    }

    /// Every German string the cook reads. Reference titles are quoted as published and left out.
    static func userFacingTexts(of recipe: Recipe) -> [String] {
        var texts = [recipe.name, recipe.tag] + recipe.authenticityChecks
        texts += [recipe.origin?.region].compactMap { $0 }
        for ingredient in recipe.ingredients {
            texts += [ingredient.name] + [ingredient.note].compactMap { $0 }
            for substitute in ingredient.substitutes {
                texts += [substitute.name] + [substitute.note].compactMap { $0 }
            }
        }
        for step in recipe.steps {
            texts += [step.phase, step.text] + [step.note].compactMap { $0 }
        }
        return texts
    }

    /// Case, diacritics, spaces and hyphens folded away, so "Gà Kho Gừng" and "Ga-Kho Gung" are one dish.
    static func normalized(_ text: String) -> String {
        TextFold.words(text).joined()
    }

    static func withoutParentheses(_ text: String) -> String {
        text.replacing(/\s*\([^)]*\)/, with: "")
    }
}
