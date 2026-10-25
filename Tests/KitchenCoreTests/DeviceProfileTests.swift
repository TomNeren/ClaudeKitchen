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
