import Foundation

/// What a rewrite changed in a recipe, for the list the cook sees next to the variant.
public struct RecipeChange: Sendable, Hashable {
    public var rule: SwapRuleID
    /// The ingredient the rule applied to, as it was in the original recipe.
    public var ingredient: IngredientID
    /// The ingredient that now carries the new food: the same ID for a full swap, a new one for a partial swap.
    public var newIngredient: IngredientID
}

/// A rule that matched an ingredient but was not applied, and why.
public struct SkippedSwap: Sendable, Hashable {
    public enum Reason: Sendable, Hashable {
        /// A partial swap needs a measured amount to split.
        case amountToTaste
        /// The extra cooking time would push a step past the device's limit.
        case exceedsMaxDuration(StepID)
    }

    public var rule: SwapRuleID
    public var ingredient: IngredientID
    public var reason: Reason
}

/// The result of rewriting a recipe for a goal.
public struct RecipeRewrite: Sendable, Hashable {
    public var recipe: Recipe
    public var changes: [RecipeChange]
    public var skipped: [SkippedSwap]
}

extension Recipe {
    /// A variant of the recipe with `goal`'s swaps applied, under the ID `<recipe>-<goal>`. Seasonings and
    /// aromatics stay as they are, because rules may not target them (`RewriteRules.issues(in:)`). The variant keeps
    /// the original ingredient as a substitute, so the cook can switch back. Extra cooking time lengthens the steps
    /// and the total time.
    public func rewritten(for goal: RewriteGoal, profile: DeviceProfile = .omniCook) -> RecipeRewrite {
        var variant = Recipe(
            id: RecipeID("\(id.rawValue)-\(goal.id.rawValue)"), name: name, tag: tag, baseServings: baseServings,
            totalMinutes: totalMinutes, ingredients: ingredients, steps: steps, verified: false,
            schemaVersion: schemaVersion)
        var changes: [RecipeChange] = []
        var skipped: [SkippedSwap] = []
        for ingredient in ingredients where ingredient.eaten {
            guard let rule = goal.rules.first(where: { $0.from == ingredient.food }) else { continue }
            if let reason = variant.blocker(for: rule, on: ingredient, profile: profile) {
                skipped.append(SkippedSwap(rule: rule.id, ingredient: ingredient.id, reason: reason))
                continue
            }
            let newID = variant.apply(rule, to: ingredient)
            changes.append(RecipeChange(rule: rule.id, ingredient: ingredient.id, newIngredient: newID))
        }
        return RecipeRewrite(recipe: variant, changes: changes, skipped: skipped)
    }

    private func blocker(for rule: SwapRule, on ingredient: Ingredient, profile: DeviceProfile) -> SkippedSwap.Reason? {
        if rule.share < 1, ingredient.amount == .toTaste {
            return .amountToTaste
        }
        for step in steps where step.ingredientIDs.contains(ingredient.id) {
            if let duration = step.timerDuration, duration + rule.extraTime > profile.maxDuration {
                return .exceedsMaxDuration(step.id)
            }
        }
        return nil
    }

    /// Applies `rule` to `ingredient` and returns the ID of the ingredient that now holds the new food.
    private mutating func apply(_ rule: SwapRule, to ingredient: Ingredient) -> IngredientID {
        guard let index = ingredients.firstIndex(where: { $0.id == ingredient.id }) else { return ingredient.id }
        let original = Substitute(name: ingredient.name, ratio: 1 / rule.ratio, note: "Original")
        let newID: IngredientID
        if rule.share >= 1 {
            newID = ingredient.id
            ingredients[index].name = rule.toName
            ingredients[index].food = rule.to
            ingredients[index].amount = ingredient.amount.multiplied(by: rule.ratio)
            ingredients[index].substitutes = [original]
        } else {
            newID = IngredientID("\(ingredient.id.rawValue)-\(rule.id.rawValue)")
            ingredients[index].amount = ingredient.amount.multiplied(by: 1 - rule.share)
            let added = Ingredient(
                id: newID, name: rule.toName, amount: ingredient.amount.multiplied(by: rule.share * rule.ratio),
                food: rule.to, scales: ingredient.scales, substitutes: [original])
            ingredients.insert(added, at: index + 1)
        }
        for stepIndex in steps.indices {
            guard let position = steps[stepIndex].ingredientIDs.firstIndex(of: ingredient.id) else { continue }
            if newID != ingredient.id {
                steps[stepIndex].ingredientIDs.insert(newID, at: position + 1)
            }
            if let duration = steps[stepIndex].setting?.duration, duration > .zero, rule.extraTime > .zero {
                steps[stepIndex].setting?.duration = duration + rule.extraTime
                totalMinutes += Int((Double(rule.extraTime.components.seconds) / 60).rounded(.up))
            }
            if let note = rule.stepNote {
                steps[stepIndex].note = [steps[stepIndex].note, note].compactMap { $0 }.joined(separator: " ")
            }
        }
        return newID
    }
}

extension Amount {
    fileprivate func multiplied(by factor: Double) -> Amount {
        switch self {
        case .measured(let value, let unit): return .measured(value * factor, unit)
        case .toTaste: return .toTaste
        }
    }
}
