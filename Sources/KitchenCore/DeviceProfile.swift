import Foundation

/// Limits and rules of one device model. Recipes are checked against it before they reach the cook.
public struct DeviceProfile: Sendable, Hashable {
    public var name: String
    /// Temperatures the manual mode accepts, in °C.
    public var temperatureRange: ClosedRange<Int>
    /// Steps of the temperature dial, in °C.
    public var temperatureStep: Int
    public var forwardSpeeds: ClosedRange<Int>
    public var reverseSpeeds: ClosedRange<Int>
    public var maxDuration: Duration
    /// Fill mark of the pot.
    public var maxFillLiters: Double
    /// Accessories the cook owns.
    public var ownedAccessories: Set<Accessory>

    public init(
        name: String, temperatureRange: ClosedRange<Int>, forwardSpeeds: ClosedRange<Int>,
        reverseSpeeds: ClosedRange<Int>, maxDuration: Duration, maxFillLiters: Double,
        ownedAccessories: Set<Accessory>, temperatureStep: Int = 5
    ) {
        self.name = name
        self.temperatureRange = temperatureRange
        self.temperatureStep = temperatureStep
        self.forwardSpeeds = forwardSpeeds
        self.reverseSpeeds = reverseSpeeds
        self.maxDuration = maxDuration
        self.maxFillLiters = maxFillLiters
        self.ownedAccessories = ownedAccessories
    }

    /// TOKIT Omni Cook (original, 2.2 l), values from the manual as evaluated on 2026-10-23.
    /// The lower temperature bound comes from reviews (see PLAN.md, section 6).
    public static let omniCook = DeviceProfile(
        name: "TOKIT Omni Cook",
        temperatureRange: 35...180,
        forwardSpeeds: 1...10,
        reverseSpeeds: 1...10,
        maxDuration: .seconds(99 * 60),
        maxFillLiters: 2.2,
        ownedAccessories: [.steamer, .basket, .whisk]
    )
}

/// Something `DeviceProfile.validate` found in a recipe.
public struct ValidationIssue: Sendable, Hashable {
    public enum Severity: Sendable, Hashable, Comparable {
        case warning
        case error
    }

    public enum Kind: Sendable, Hashable {
        case noSteps
        case invalidBaseServings(Int)
        case duplicateIngredientID(IngredientID)
        case duplicateStepID(StepID)
        case unknownIngredient(IngredientID)
        case temperatureOutOfRange(Int)
        case speedOutOfRange(Rotation)
        case durationOutOfRange(Duration)
        case steamWithoutSteamer
        case steamWithRotation
        case accessoryNotOwned(Accessory)
        case fillLevelExceeded(liters: Double)
        /// The ingredient's food must boil for `required` (`Food.mustBoil`), but the steps from the one that adds it
        /// up to the next fresh pot boil it for less.
        case boilsTooShort(IngredientID, required: Duration)
    }

    public var kind: Kind
    /// The step the issue belongs to, nil for recipe-wide issues.
    public var stepID: StepID?

    public init(kind: Kind, stepID: StepID? = nil) {
        self.kind = kind
        self.stepID = stepID
    }

    public var severity: Severity {
        switch kind {
        case .fillLevelExceeded, .accessoryNotOwned, .boilsTooShort:
            return .warning
        default:
            return .error
        }
    }
}

extension DeviceProfile {
    /// Checks `recipe` for `servings` against this device. Errors mean the recipe cannot be cooked as written;
    /// warnings are shown to the cook but do not block.
    /// `catalog` weighs ingredients given in pieces or spoons for the fill check; see `estimatedFillLiters`.
    public func validate(
        _ recipe: Recipe, servings: Int? = nil, catalog: FoodCatalog? = FoodCatalog.shared
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        if recipe.steps.isEmpty {
            issues.append(ValidationIssue(kind: .noSteps))
        }
        guard recipe.baseServings > 0 else {
            issues.append(ValidationIssue(kind: .invalidBaseServings(recipe.baseServings)))
            return issues
        }

        var ingredientIDs: Set<IngredientID> = []
        for ingredient in recipe.ingredients where !ingredientIDs.insert(ingredient.id).inserted {
            issues.append(ValidationIssue(kind: .duplicateIngredientID(ingredient.id)))
        }
        var stepIDs: Set<StepID> = []
        for step in recipe.steps {
            if !stepIDs.insert(step.id).inserted {
                issues.append(ValidationIssue(kind: .duplicateStepID(step.id)))
            }
            for id in step.ingredientIDs where !ingredientIDs.contains(id) {
                issues.append(ValidationIssue(kind: .unknownIngredient(id), stepID: step.id))
            }
            issues += validate(step).map { ValidationIssue(kind: $0, stepID: step.id) }
        }

        let liters = estimatedFillLiters(of: recipe, servings: servings ?? recipe.baseServings, catalog: catalog)
        if liters > maxFillLiters {
            issues.append(ValidationIssue(kind: .fillLevelExceeded(liters: liters)))
        }
        if let catalog {
            issues += boilIssues(in: recipe, catalog: catalog)
        }
        return issues
    }

    /// A warning, not an error: canned beans map to the same food and are safe without the long boil.
    private func boilIssues(in recipe: Recipe, catalog: FoodCatalog) -> [ValidationIssue] {
        recipe.ingredients.compactMap { ingredient in
            guard let rule = catalog.food(for: ingredient)?.mustBoil,
                let first = recipe.steps.firstIndex(where: { $0.ingredientIDs.contains(ingredient.id) })
            else { return nil }
            var boiled = Duration.zero
            for index in recipe.steps.indices[first...] {
                if index > first && recipe.steps[index].freshPot { break }
                guard let setting = recipe.steps[index].setting, case .celsius(let celsius) = setting.heat,
                    celsius >= 100, let duration = setting.duration
                else { continue }
                boiled += duration
            }
            guard boiled < rule.duration else { return nil }
            return ValidationIssue(
                kind: .boilsTooShort(ingredient.id, required: rule.duration), stepID: recipe.steps[first].id)
        }
    }

    private func validate(_ step: Step) -> [ValidationIssue.Kind] {
        var kinds: [ValidationIssue.Kind] = []

        if let accessory = step.accessory, !ownedAccessories.contains(accessory) {
            kinds.append(.accessoryNotOwned(accessory))
        }
        guard let setting = step.setting else { return kinds }

        let isSteam = setting.heat == .steam || setting.program == .steam
        if isSteam {
            if step.accessory != .steamer {
                kinds.append(.steamWithoutSteamer)
            }
            if setting.rotation != nil {
                kinds.append(.steamWithRotation)
            }
        }
        if case .celsius(let celsius) = setting.heat, !temperatureRange.contains(celsius) {
            kinds.append(.temperatureOutOfRange(celsius))
        }
        if let rotation = setting.rotation {
            let allowed: ClosedRange<Int>
            switch rotation {
            case .forward:
                allowed = forwardSpeeds
            case .reverse:
                allowed = reverseSpeeds
            }
            if !allowed.contains(rotation.speed) {
                kinds.append(.speedOutOfRange(rotation))
            }
        }
        if let duration = setting.duration, duration <= .zero || duration > maxDuration {
            kinds.append(.durationOutOfRange(duration))
        }
        return kinds
    }

    /// Rough fill level of the fullest pot: every gram counts as one millilitre. Ingredients in pieces, cloves or
    /// spoons count with their catalog weight when `catalog` knows their food; without one they are left out.
    ///
    /// A step with `freshPot` starts a new pot. An ingredient counts in every pot a step adds it to outside the
    /// steamer, so something taken out and put back into a fresh pot counts there too; ingredients that only go into
    /// the steamer are not in the pot, ingredients no step mentions count in the first pot.
    public func estimatedFillLiters(
        of recipe: Recipe, servings: Int, catalog: FoodCatalog? = FoodCatalog.shared
    ) -> Double {
        var potsOfIngredient: [IngredientID: Set<Int>] = [:]
        var steamerOnly: Set<IngredientID> = []
        var pot = 0
        for step in recipe.steps {
            if step.freshPot, step.id != recipe.steps.first?.id {
                pot += 1
            }
            for id in step.ingredientIDs {
                if step.accessory == .steamer {
                    if potsOfIngredient[id] == nil {
                        steamerOnly.insert(id)
                    }
                } else {
                    potsOfIngredient[id, default: []].insert(pot)
                    steamerOnly.remove(id)
                }
            }
        }

        var gramsPerPot = Array(repeating: 0.0, count: pot + 1)
        for ingredient in recipe.ingredients where !steamerOnly.contains(ingredient.id) {
            let amount = ingredient.amount(from: recipe.baseServings, to: servings)
            let grams: Double?
            if case .measured(let value, .gram) = amount {
                grams = value
            } else {
                grams = catalog?.food(for: ingredient)?.grams(of: amount)
            }
            guard let grams else { continue }
            for index in potsOfIngredient[ingredient.id] ?? [0] {
                gramsPerPot[index] += grams
            }
        }
        return (gramsPerPot.max() ?? 0) / 1000
    }

    /// Servings to offer for `recipe`: `CookingSession.defaultServingsRange`, capped so the pot stays below the fill
    /// mark, but never below the recipe's own base servings.
    public func servingsRange(for recipe: Recipe, catalog: FoodCatalog? = FoodCatalog.shared) -> ClosedRange<Int> {
        let range = CookingSession.defaultServingsRange
        let fitting = max(recipe.baseServings, maxServings(for: recipe, limit: range.upperBound, catalog: catalog))
        return range.lowerBound...max(range.lowerBound, min(fitting, range.upperBound))
    }

    /// The largest number of servings, up to `limit`, for which the recipe stays below the fill mark.
    public func maxServings(for recipe: Recipe, limit: Int = 12, catalog: FoodCatalog? = FoodCatalog.shared) -> Int {
        var best = 1
        for servings in 1...max(1, limit)
        where estimatedFillLiters(of: recipe, servings: servings, catalog: catalog) <= maxFillLiters {
            best = servings
        }
        return best
    }
}
