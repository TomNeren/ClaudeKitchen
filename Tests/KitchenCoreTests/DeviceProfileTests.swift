import Testing

@testable import KitchenCore

@Suite("Device validation")
struct DeviceProfileTests {
    private let profile = DeviceProfile.omniCook

    private func recipe(
        steps: [Step], ingredients: [Ingredient] = [], baseServings: Int = 2
    ) -> Recipe {
        Recipe(
            id: "test", name: "Test", tag: "", baseServings: baseServings, totalMinutes: 10,
            ingredients: ingredients, steps: steps)
    }

    private func kinds(_ setting: DeviceSetting, accessory: Accessory? = nil) -> [ValidationIssue.Kind] {
        let step = Step(id: "s1", phase: "P", text: "T", setting: setting, accessory: accessory)
        return profile.validate(recipe(steps: [step])).map(\.kind)
    }

    @Test func acceptsSettingsWithinLimits() {
        #expect(
            kinds(DeviceSetting(heat: .celsius(120), rotation: .reverse(speed: 1), duration: .seconds(180))).isEmpty)
    }

    @Test(arguments: [34, 181])
    func rejectsTemperatureOutsideRange(celsius: Int) {
        #expect(kinds(DeviceSetting(heat: .celsius(celsius))) == [.temperatureOutOfRange(celsius)])
    }

    @Test(arguments: [Rotation.forward(speed: 0), .forward(speed: 11), .reverse(speed: 11)])
    func rejectsSpeedOutsideRange(rotation: Rotation) {
        #expect(kinds(DeviceSetting(rotation: rotation)) == [.speedOutOfRange(rotation)])
    }

    @Test(arguments: [Duration.zero, .seconds(99 * 60 + 1)])
    func rejectsDurationOutsideRange(duration: Duration) {
        #expect(kinds(DeviceSetting(duration: duration)) == [.durationOutOfRange(duration)])
    }

    @Test func steamNeedsTheSteamerAndNoRotation() {
        let setting = DeviceSetting(program: .steam, heat: .steam, rotation: .forward(speed: 2))
        #expect(kinds(setting) == [.steamWithoutSteamer, .steamWithRotation])
        #expect(kinds(DeviceSetting(program: .steam, heat: .steam), accessory: .steamer).isEmpty)
    }

    @Test func warnsWhenAccessoryIsNotOwned() {
        var withoutSteamer = profile
        withoutSteamer.ownedAccessories = []
        let step = Step(id: "s1", phase: "P", text: "T", accessory: .steamer)
        let issues = withoutSteamer.validate(recipe(steps: [step]))
        #expect(issues == [ValidationIssue(kind: .accessoryNotOwned(.steamer), stepID: "s1")])
        #expect(issues.allSatisfy { $0.severity == .warning })
    }

    @Test func allowsHighSpeedWhenHot() {
        #expect(kinds(DeviceSetting(heat: .celsius(120), rotation: .forward(speed: 10))).isEmpty)
    }

    @Test func flagsBrokenStructure() {
        let ingredient = Ingredient(id: "a", name: "A", amount: .toTaste)
        let steps = [
            Step(id: "s1", phase: "P", text: "T", ingredientIDs: ["missing"]),
            Step(id: "s1", phase: "P", text: "T"),
        ]
        let issues = profile.validate(recipe(steps: steps, ingredients: [ingredient, ingredient]))
        #expect(
            Set(issues.map(\.kind)) == [
                .duplicateIngredientID("a"), .duplicateStepID("s1"), .unknownIngredient("missing"),
            ])
        #expect(profile.validate(recipe(steps: [])).map(\.kind) == [.noSteps])
        #expect(profile.validate(recipe(steps: steps, baseServings: 0)).map(\.kind) == [.invalidBaseServings(0)])
    }

    @Test func fillLevelCountsGramsOfTheFullestPotOnly() {
        let ingredients = [
            Ingredient(id: "broth", name: "Brühe", amount: .measured(1000, .gram)),
            Ingredient(id: "fish", name: "Fisch", amount: .measured(800, .gram)),
            Ingredient(id: "side", name: "Beilage", amount: .measured(600, .gram)),
            Ingredient(id: "onion", name: "Zwiebel", amount: .measured(1, .piece)),
        ]
        let steps = [
            Step(id: "s1", phase: "P", text: "T", ingredientIDs: ["broth", "onion"]),
            Step(id: "s2", phase: "P", text: "T", ingredientIDs: ["fish"], accessory: .steamer),
            Step(id: "s3", phase: "P", text: "T", ingredientIDs: ["side"], freshPot: true),
        ]
        let recipe = recipe(steps: steps, ingredients: ingredients)
        #expect(profile.estimatedFillLiters(of: recipe, servings: 2) == 1.0)
        #expect(profile.estimatedFillLiters(of: recipe, servings: 4) == 2.0)
        #expect(profile.maxServings(for: recipe) == 4)
        #expect(profile.validate(recipe, servings: 6).map(\.kind) == [.fillLevelExceeded(liters: 3.0)])
        #expect(profile.servingsRange(for: recipe) == 1...4)
        #expect(profile.servingsRange(for: self.recipe(steps: steps, ingredients: [], baseServings: 2)) == 1...8)
    }
}

@Suite("Fill level with catalog weights")
struct FillLevelCatalogTests {
    private static let catalog = FoodCatalog(
        sources: [], groups: [FoodGroup(id: "g", name: "G", direction: .notAssessed)],
        foods: [Food(id: "eggplant", name: "Aubergine", group: "g", role: .base, gramsPerUnit: [.piece: 250])])

    private static let recipe = Recipe(
        id: "r", name: "R", tag: "", baseServings: 1, totalMinutes: 10,
        ingredients: [
            Ingredient(id: "water", name: "Wasser", amount: .measured(500, .gram)),
            Ingredient(id: "eggplant", name: "Aubergine", amount: .measured(2, .piece), food: "eggplant"),
        ],
        steps: [Step(id: "s1", phase: "", text: "", ingredientIDs: ["water", "eggplant"])])

    @Test func piecesCountWithTheirCatalogWeight() {
        #expect(DeviceProfile.omniCook.estimatedFillLiters(of: Self.recipe, servings: 1, catalog: Self.catalog) == 1)
        #expect(DeviceProfile.omniCook.estimatedFillLiters(of: Self.recipe, servings: 1, catalog: nil) == 0.5)
    }

    @Test func servingsRangeShrinksWhenPiecesAreWeighed() {
        #expect(DeviceProfile.omniCook.maxServings(for: Self.recipe, catalog: Self.catalog) == 2)
        #expect(DeviceProfile.omniCook.maxServings(for: Self.recipe, catalog: nil) == 4)
    }
}

@Suite("Fill level across pots")
struct FillLevelPotsTests {
    @Test func anIngredientPutBackIntoAFreshPotCountsThereToo() {
        let recipe = Recipe(
            id: "r", name: "R", tag: "", baseServings: 1, totalMinutes: 10,
            ingredients: [
                Ingredient(id: "egg", name: "Ei", amount: .measured(800, .gram)),
                Ingredient(id: "tomato", name: "Tomate", amount: .measured(800, .gram)),
            ],
            steps: [
                Step(id: "s1", phase: "", text: "", ingredientIDs: ["egg"]),
                Step(id: "s2", phase: "", text: "", ingredientIDs: ["tomato"], freshPot: true),
                Step(id: "s3", phase: "", text: "", ingredientIDs: ["egg"]),
            ])
        #expect(DeviceProfile.omniCook.estimatedFillLiters(of: recipe, servings: 1, catalog: nil) == 1.6)
    }
}

@Suite("Boil requirement")
struct BoilRequirementTests {
    private static let catalog = FoodCatalog(
        sources: [EvidenceSource(id: "bfr", citation: "BfR", year: 2024)],
        groups: [FoodGroup(id: "g", name: "G", direction: .notAssessed)],
        foods: [
            Food(
                id: "beans", name: "Bohnen", group: "g", role: .base, nutrientsUnavailable: true,
                mustBoil: BoilRequirement(duration: .seconds(1800), sourceID: "bfr", quote: "30 Minuten kochen"))
        ])

    private static func step(_ id: StepID, _ heat: Heat?, seconds: Int, beans: Bool = false, freshPot: Bool = false)
        -> Step
    {
        Step(
            id: id, phase: "", text: "", ingredientIDs: beans ? ["beans"] : [],
            setting: DeviceSetting(heat: heat, duration: .seconds(seconds)), freshPot: freshPot)
    }

    private static func issues(_ steps: [Step]) -> [ValidationIssue] {
        let recipe = Recipe(
            id: "r", name: "R", tag: "", baseServings: 1, totalMinutes: 60,
            ingredients: [Ingredient(id: "beans", name: "Bohnen", amount: .measured(100, .gram), food: "beans")],
            steps: steps)
        return DeviceProfile.omniCook.validate(recipe, catalog: catalog).filter {
            if case .boilsTooShort = $0.kind { return true }
            return false
        }
    }

    @Test func boilingStepsAfterTheBeansGoInAddUp() {
        let enough = [
            Self.step("s1", .celsius(110), seconds: 900, beans: true), Self.step("s2", .celsius(100), seconds: 900),
        ]
        #expect(Self.issues(enough).isEmpty)
    }

    @Test func warnsWhenTheBeansBoilTooShortOrBelow100Degrees() {
        let short = [
            Self.step("s1", .celsius(100), seconds: 600, beans: true), Self.step("s2", .celsius(95), seconds: 3600),
        ]
        let issue = ValidationIssue(kind: .boilsTooShort("beans", required: .seconds(1800)), stepID: "s1")
        #expect(Self.issues(short) == [issue])
        #expect(issue.severity == .warning)
    }

    @Test func boilingBeforeTheBeansOrInAFreshPotDoesNotCount() {
        let steps = [
            Self.step("s1", .celsius(100), seconds: 1800), Self.step("s2", .celsius(100), seconds: 60, beans: true),
            Self.step("s3", .celsius(100), seconds: 1800, freshPot: true),
        ]
        #expect(Self.issues(steps).map(\.stepID) == ["s2"])
    }

    @Test func steamDoesNotCount() {
        #expect(Self.issues([Self.step("s1", .steam, seconds: 3600, beans: true)]).count == 1)
    }

    @Test func theSteamerAndSteamProgramDoNotCount() {
        var basket = Self.step("s1", .celsius(100), seconds: 3600, beans: true)
        basket.accessory = .steamer
        var program = Self.step("s1", .celsius(100), seconds: 3600, beans: true)
        program.setting?.program = .steam
        #expect(Self.issues([basket]).count == 1)
        #expect(Self.issues([program]).count == 1)
    }

    @Test func beansPutBackIntoAFreshPotCountThere() {
        let steps = [
            Self.step("s1", nil, seconds: 60, beans: true),
            Self.step("s2", .celsius(100), seconds: 1800, beans: true, freshPot: true),
        ]
        #expect(Self.issues(steps).isEmpty)
    }
}
