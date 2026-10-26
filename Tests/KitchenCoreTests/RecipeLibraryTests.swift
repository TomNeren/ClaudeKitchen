import Foundation
import Testing

@testable import KitchenCore

@Suite("Bundled recipes")
struct RecipeLibraryTests {
    @Test func loadsAllBundledRecipes() throws {
        let recipes = try RecipeLibrary.bundled()
        let directory = try #require(Bundle.module.url(forResource: "Recipes", withExtension: nil))
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        #expect(recipes.count == files.count)
        #expect(Set(recipes.map(\.id.rawValue)).count == recipes.count, "duplicate recipe IDs")
        #expect(
            Set(recipes.map(\.id.rawValue) + files.map { $0.deletingPathExtension().lastPathComponent }).count
                == recipes.count, "file name and recipe ID differ")
        for id in ["ingwer-lachs-pak-choi", "kichererbsen-spinat-curry", "zitronen-linsen-eintopf"] {
            #expect(recipes.contains { $0.id.rawValue == id }, "\(id)")
        }
    }

    @Test func everyIngredientIsUsedInSomeStep() throws {
        for recipe in try RecipeLibrary.bundled() {
            let used = Set(recipe.steps.flatMap(\.ingredientIDs))
            for ingredient in recipe.ingredients {
                #expect(used.contains(ingredient.id), "\(recipe.id): \(ingredient.id) is in no step")
            }
        }
    }

    @Test func everyBundledRecipePassesValidationWithoutErrors() throws {
        for recipe in try RecipeLibrary.bundled() {
            let issues = DeviceProfile.omniCook.validate(recipe)
            #expect(issues.isEmpty, "\(recipe.id): \(issues)")
        }
    }

    @Test func substitutesAreNamedWithAPositiveRatioAndDifferFromTheOriginal() throws {
        for recipe in try RecipeLibrary.bundled() {
            for ingredient in recipe.ingredients {
                for substitute in ingredient.substitutes {
                    #expect(!substitute.name.isEmpty && substitute.ratio > 0, "\(recipe.id)/\(ingredient.id)")
                    #expect(substitute.name != ingredient.name, "\(recipe.id)/\(ingredient.id)")
                }
            }
        }
    }

    @Test func everyBundledRecipeRoundTripsThroughJSON() throws {
        for recipe in try RecipeLibrary.bundled() {
            let data = try JSONEncoder().encode(recipe)
            #expect(try RecipeLibrary.decode(data) == recipe, "\(recipe.id)")
        }
    }

    @Test func rejectsNewerSchemaVersion() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "future-\(UUID().uuidString).json")
        let json = """
            {"schemaVersion": 99, "id": "x", "name": "X", "tag": "", "baseServings": 1, "totalMinutes": 1,
             "verified": false, "ingredients": [], "steps": []}
            """
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: RecipeLibrary.LoadError.unsupportedSchemaVersion(file: url.lastPathComponent, version: 99)) {
            try RecipeLibrary.load(from: url)
        }
    }

    @Test func decodesTheLentilStewAsWritten() throws {
        let recipe = try #require(try RecipeLibrary.bundled().first { $0.id == "zitronen-linsen-eintopf" })
        #expect(recipe.baseServings == 3)
        #expect(recipe.ingredient("pfeffer")?.amount == .toTaste)
        #expect(recipe.ingredient("lorbeer")?.scales == false)
        #expect(
            recipe.steps[1].setting
                == DeviceSetting(
                    heat: .celsius(120), rotation: .reverse(speed: 1),
                    duration: .seconds(180)))
        #expect(recipe.steps[0].timerDuration == .seconds(5))
        #expect(recipe.steps[2].timerDuration == nil)
    }

    @Test func substitutesScaleWithServingsAndRatio() throws {
        let curry = try #require(try RecipeLibrary.bundled().first { $0.id == "kichererbsen-spinat-curry" })
        let ginger = try #require(curry.ingredient("ingwer"))
        let options = ginger.substitutions(from: curry.baseServings, to: 6)
        #expect(options.map(\.substitute.name) == ["Ingwerpulver"])
        #expect(options.map(\.amount) == [.measured(4, .gram)])
        #expect(try #require(curry.ingredient("salz")).substitutions(from: 3, to: 6).isEmpty)
    }
}
