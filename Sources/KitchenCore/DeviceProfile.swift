import Foundation

/// Limits and rules of one device model. Recipes are checked against it before they reach the cook.
public struct DeviceProfile: Sendable, Hashable {
    public var name: String
    /// Temperatures the manual mode accepts, in °C.
    public var temperatureRange: ClosedRange<Int>
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
        ownedAccessories: Set<Accessory>
    ) {
        self.name = name
        self.temperatureRange = temperatureRange
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
        case .fillLevelExceeded, .accessoryNotOwned:
            return .warning
        default:
            return .error
        }
    }
}

extension DeviceProfile {
    /// Checks `recipe` for `servings` against this device. Errors mean the recipe cannot be cooked as written;
    /// warnings are shown to the cook but do not block.
    public func validate(_ recipe: Recipe, servings: Int? = nil) -> [ValidationIssue] {
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

        let liters = estimatedFillLiters(of: recipe, servings: servings ?? recipe.baseServings)
        if liters > maxFillLiters {
            issues.append(ValidationIssue(kind: .fillLevelExceeded(liters: liters)))
        }
        return issues
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

    /// Rough fill level of the fullest pot: every ingredient measured in grams counts as one millilitre.
    ///
    /// A step with `freshPot` starts a new pot. An ingredient counts in the pot of the first step that adds it outside
    /// the steamer; ingredients that only go into the steamer are not in the pot, ingredients no step mentions count
    /// in the first pot.
    public func estimatedFillLiters(of recipe: Recipe, servings: Int) -> Double {
        var potOfIngredient: [IngredientID: Int] = [:]
        var steamerOnly: Set<IngredientID> = []
        var pot = 0
        for step in recipe.steps {
            if step.freshPot, step.id != recipe.steps.first?.id {
                pot += 1
            }
            for id in step.ingredientIDs {
                if step.accessory == .steamer {
                    if potOfIngredient[id] == nil {
                        steamerOnly.insert(id)
                    }
                } else if potOfIngredient[id] == nil {
                    potOfIngredient[id] = pot
                    steamerOnly.remove(id)
                }
            }
        }

        var gramsPerPot = Array(repeating: 0.0, count: pot + 1)
        for ingredient in recipe.ingredients where !steamerOnly.contains(ingredient.id) {
            if case .measured(let value, .gram) = ingredient.amount(from: recipe.baseServings, to: servings) {
                gramsPerPot[potOfIngredient[ingredient.id] ?? 0] += value
            }
        }
        return (gramsPerPot.max() ?? 0) / 1000
    }

    /// The largest number of servings, up to `limit`, for which the recipe stays below the fill mark.
    public func maxServings(for recipe: Recipe, limit: Int = 12) -> Int {
        var best = 1
        for servings in 1...max(1, limit) where estimatedFillLiters(of: recipe, servings: servings) <= maxFillLiters {
            best = servings
        }
        return best
    }
}
