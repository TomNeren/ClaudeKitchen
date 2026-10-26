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
    /// A variant of the recipe with `goal`'s swaps applied, under the ID `<recipe>-<goal>`. Pass a goal from
    /// `RewriteRules.resolved(_:)` so inherited rules apply too. A recipe that already is a variant (`variantOf`)
    /// comes back unchanged. Seasonings and aromatics stay as they are, because rules may not target them
    /// (`RewriteRules.issues(in:)`); the one exception is a seasoning's declared low-sodium version under the sodium
    /// criterion (decision 33). The swapped ingredient offers the original as its first substitute.
    ///
    /// Extra cooking time goes once onto the step that cooks the swapped food: the longest heated, timed step from
    /// the step that adds it up to the next fresh pot. The total time grows by the same amount.
    public func rewritten(
        for goal: RewriteGoal, catalog: FoodCatalog, profile: DeviceProfile = .omniCook
    ) -> RecipeRewrite {
        guard variantOf == nil else { return RecipeRewrite(recipe: self, changes: [], skipped: []) }
        var variant = Recipe(
            id: RecipeID("\(id.rawValue)-\(goal.id.rawValue)"), name: name, tag: tag, baseServings: baseServings,
            totalMinutes: totalMinutes, ingredients: ingredients, steps: steps, verified: false, variantOf: id,
            schemaVersion: schemaVersion)
        var changes: [RecipeChange] = []
        var skipped: [SkippedSwap] = []
        for ingredient in ingredients where ingredient.eaten {
            guard let rule = goal.rules.first(where: { $0.from == ingredient.food }) else { continue }
            let cookingStep = rule.extraTime > .zero ? variant.cookingStep(for: ingredient.id) : nil
            if let reason = variant.blocker(for: rule, on: ingredient, cookingStep: cookingStep, profile: profile) {
                skipped.append(SkippedSwap(rule: rule.id, ingredient: ingredient.id, reason: reason))
                continue
            }
            let newID = variant.apply(rule, to: ingredient, cookingStep: cookingStep, catalog: catalog)
            changes.append(RecipeChange(rule: rule.id, ingredient: ingredient.id, newIngredient: newID))
        }
        return RecipeRewrite(recipe: variant, changes: changes, skipped: skipped)
    }

    /// Index of the longest heated, timed step from the first step that adds `ingredient` up to the next fresh pot.
    private func cookingStep(for ingredient: IngredientID) -> Int? {
        guard let first = steps.firstIndex(where: { $0.ingredientIDs.contains(ingredient) }) else { return nil }
        var best: (index: Int, duration: Duration)?
        for index in steps.indices[first...] {
            if index > first && steps[index].freshPot { break }
            guard steps[index].setting?.heat != nil, let duration = steps[index].timerDuration else { continue }
            if best.map({ duration > $0.duration }) ?? true {
                best = (index, duration)
            }
        }
        return best?.index
    }

    private func blocker(
        for rule: SwapRule, on ingredient: Ingredient, cookingStep: Int?, profile: DeviceProfile
    ) -> SkippedSwap.Reason? {
        if rule.share < 1, ingredient.amount == .toTaste {
            return .amountToTaste
        }
        if let cookingStep, let duration = steps[cookingStep].timerDuration,
            duration + rule.extraTime > profile.maxDuration
        {
            return .exceedsMaxDuration(steps[cookingStep].id)
        }
        return nil
    }

    /// Applies `rule` to `ingredient` and returns the ID of the ingredient that now holds the new food.
    private mutating func apply(
        _ rule: SwapRule, to ingredient: Ingredient, cookingStep: Int?, catalog: FoodCatalog
    ) -> IngredientID {
        guard let index = ingredients.firstIndex(where: { $0.id == ingredient.id }) else { return ingredient.id }
        let (amount, back) = ingredient.amount.swapped(
            share: rule.share, ratio: rule.ratio, from: catalog.food(rule.from), to: catalog.food(rule.to))
        let original = Substitute(name: ingredient.name, ratio: back, note: "Original")
        let newID: IngredientID
        if rule.share >= 1 {
            newID = ingredient.id
            ingredients[index].name = rule.toName
            ingredients[index].food = rule.to
            ingredients[index].amount = amount
            ingredients[index].substitutes = [original] + ingredient.substitutes
        } else {
            newID = uniqueIngredientID("\(ingredient.id.rawValue)-\(rule.id.rawValue)")
            ingredients[index].amount = ingredient.amount.multiplied(by: 1 - rule.share)
            let added = Ingredient(
                id: newID, name: rule.toName, amount: amount, food: rule.to, scales: ingredient.scales,
                substitutes: [original])
            ingredients.insert(added, at: index + 1)
        }
        if newID != ingredient.id {
            for stepIndex in steps.indices {
                guard let position = steps[stepIndex].ingredientIDs.firstIndex(of: ingredient.id) else { continue }
                steps[stepIndex].ingredientIDs.insert(newID, at: position + 1)
            }
        }
        if let cookingStep, let duration = steps[cookingStep].setting?.duration {
            steps[cookingStep].setting?.duration = duration + rule.extraTime
            totalMinutes += Int((Double(rule.extraTime.components.seconds) / 60).rounded(.up))
        }
        let noteStep = cookingStep ?? steps.firstIndex { $0.ingredientIDs.contains(ingredient.id) }
        if let note = rule.stepNote, let noteStep {
            steps[noteStep].note = [steps[noteStep].note, note].compactMap { $0 }.joined(separator: " ")
        }
        return newID
    }

    private func uniqueIngredientID(_ base: String) -> IngredientID {
        let taken = Set(ingredients.map(\.id.rawValue))
        var candidate = base
        var number = 2
        while taken.contains(candidate) {
            candidate = "\(base)-\(number)"
            number += 1
        }
        return IngredientID(candidate)
    }
}

extension Amount {
    fileprivate func multiplied(by factor: Double) -> Amount {
        switch self {
        case .measured(let value, let unit): return .measured(value * factor, unit)
        case .toTaste: return .toTaste
        }
    }

    /// The amount of `to` that replaces `share` of this amount of `from`, with `ratio` grams of `to` per gram of
    /// `from`, and the substitute ratio that leads from the new amount back to the replaced part.
    ///
    /// Grams stay grams. Other units stay as they are when both foods have a weight for them; when only `from`
    /// has one, the new amount is given in grams (3 Stk potatoes become 450 g cauliflower, not 3 heads).
    fileprivate func swapped(share: Double, ratio: Double, from: Food?, to: Food?) -> (Amount, Double) {
        guard case .measured(let value, let unit) = self else { return (.toTaste, 1 / ratio) }
        let part = value * share
        guard unit != .gram, let fromWeight = from?.gramsPerUnit[unit] else {
            return (.measured(part * ratio, unit), 1 / ratio)
        }
        guard let toWeight = to?.gramsPerUnit[unit] else {
            let grams = part * fromWeight * ratio
            // The substitute stays in grams too, so the way back is plain grams of the original.
            return (.measured(grams, .gram), 1 / ratio)
        }
        let factor = ratio * fromWeight / toWeight
        return (.measured(part * factor, unit), 1 / factor)
    }
}
