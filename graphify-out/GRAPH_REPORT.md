# Graph Report - ClaudeKitchen  (2026-10-27)

## Corpus Check
- 136 files · ~76,494 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 5 file(s) not represented in the graph (top: (none) 3, .example 1, .xcconfig 1)

## Summary
- 2507 nodes · 5386 edges · 111 communities (92 shown, 19 thin omitted)
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 474 edges (avg confidence: 0.85)
- Token cost: 137,319 input · 0 output

## Community Hubs (Navigation)
- App-Modelle und Dienste
- Startseite und Kochprotokoll
- Geräteprofil und Rezeptregeln
- Kochmodus-Oberfläche
- Mengen und Editor-Zutaten
- Live Activity und Alarme
- Siri und Schritt-Intents
- Einkauf und Vorrat UI
- Einstellungen, Schlüssel, Sprachprotokoll
- Lebensmittel und Nährwert-Tests
- Spracheingabe und Sprachausgabe
- Zutaten-Zuordnung und Rezeptqualität
- Essensplan und Vorrat
- Plan: Entscheidungen und Meilensteine
- TestFlight-Workflow
- Recipe
- Python-Werkzeuge
- Recipe Editing
- Cooking View
- Recipe Detail View
- Voice Command
- Claude Recipe Import
- Pantry
- Shopping List
- Step Editor View
- Food Catalog
- Recipe Rewrite Tests
- Recipe Editor View
- CI-Workflow
- Recipe Rewriter
- Rewrite Rules
- Recipe Image Band
- Food
- Claude Recipe Improvement
- Recipe Improvement Tests
- Recipe (2)
- Recipe Editor Model
- Recipe Detail Model
- System Alarm Scheduler
- Ingredient Editor View
- Evidence
- Cooking Session
- Cooking Session Tests
- Shopping List Tests
- Glyph
- Cooking Screen Model
- Improve Recipe Model
- Recipe Draft
- Rewrite Rules (2)
- Claude Client
- Import Recipe Model
- Recipe Origin
- Recipe Library View
- Food (2)
- Nutrition
- project
- Food Catalog (2)
- Cooking Session (2)
- Recipe Library Model
- Voice Mode Model
- Projektregeln
- Recipe Library Tests
- Rezept-Prompt und Regeln
- JSONValue
- Rewrite Rules (3)
- File Recipe Store
- Import Recipe View
- Agent Brief Tests
- Shopping Text
- Health Advisor
- Recipe Editing Tests
- Claude Recipe Import (2)
- Recipe Search Tests
- Health Goals
- Device Setting
- Aisle
- Speech Listener
- Rewrite Rules (4)
- Recipe Photo
- Claude Recipe Improvement (2)
- Food Catalog Tests
- Improve Recipe Sheet
- Recipe Search
- TestFlight-Doku
- PLAN
- Recipe Search Tests (2)
- project (2)
- project (3)
- Food Catalog (3)
- Identifier
- Cooking Status
- Step Editor View (2)
- Food Matching Tests
- project (4)
- Cooking Status Tests
- Route
- project (5)
- Cooking Assistant
- project (6)
- Cooking Screen Model (2)
- Import Recipe Model (2)
- Improve Recipe Sheet (2)
- Cook Rating Sheet
- Recipe Detail View (2)
- Voice Mode Model (2)
- Device Setting (2)
- Claude Kitchen App
- PLAN (2)
- Shopping List (2)
- Timer Alarm
- Paketdefinition

## God Nodes (most connected - your core abstractions)
1. `PLAN.md Aufbauplan` - 81 edges
2. `CookingSession` - 76 edges
3. `KitchenCore` - 69 edges
4. `Food` - 58 edges
5. `ShoppingModel` - 44 edges
6. `RecipeEditorModel` - 39 edges
7. `DeviceSetting` - 38 edges
8. `ShoppingList` - 38 edges
9. `RecipeRewriteTests` - 36 edges
10. `Amount` - 35 edges

## Surprising Connections (you probably didn't know these)
- `Geraetewerte nur ueber DeviceProfile` --references--> `DeviceProfile`  [EXTRACTED]
  CLAUDE.md → Sources/KitchenCore/DeviceProfile.swift
- `Jedes Rezept besteht validate` --references--> `DeviceProfile`  [EXTRACTED]
  CLAUDE.md → Sources/KitchenCore/DeviceProfile.swift
- `Quellen und Recht` --semantically_similar_to--> `Rezeptbestand authentisch`  [INFERRED] [semantically similar]
  Prompts/rezepte-erweitern.md → PLAN.md
- `Entscheidung 23: Sprachbefehle wie Siri` --references--> `CookingIntentTarget`  [EXTRACTED]
  PLAN.md → App/Shared/CookingIntents.swift
- `Sprachmodus drei Schichten` --references--> `CookingIntentTarget`  [EXTRACTED]
  PLAN.md → App/Shared/CookingIntents.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Sprachmodus Schichten** — plan_sprachmodus, plan_entscheidung_20, plan_entscheidung_21, plan_entscheidung_23, sources_kitchencore_voice_voicecommand_voicecommand [EXTRACTED 1.00]
- **Gesund umschreiben Fluss** — plan_evidenz_datenbank, plan_lebensmittelkatalog, plan_healthyvariant, plan_ziele, sources_kitchencore_rewrite_healthadvisor_healthadvisor [EXTRACTED 1.00]
- **TestFlight Pipeline** — app_testflight_app_store_connect, app_testflight_github_environment, app_testflight_testflight_workflow, app_testflight_build_nummern [EXTRACTED 1.00]

## Communities (111 total, 19 thin omitted)

### Community 0 - "App-Modelle und Dienste"
Cohesion: 0.06
Nodes (11): Existing, RemindersExport, EventKit, Foundation, FoundationModels, KitchenCore, Observation, PlainText (+3 more)

### Community 1 - "Startseite und Kochprotokoll"
Cohesion: 0.07
Nodes (13): CookedBadge, .body, CookedText, CookLogModel, CookLogStore, .file, RecipeCard, .body (+5 more)

### Community 2 - "Geräteprofil und Rezeptregeln"
Cohesion: 0.06
Nodes (21): TOKIT Omni Cook, Geraetegrenzen im Prompt, DeviceProfile, Kind, accessoryNotOwned, boilsTooShort, duplicateIngredientID, duplicateStepID (+13 more)

### Community 3 - "Kochmodus-Oberfläche"
Cohesion: 0.05
Nodes (19): CookingActivityAttributes.ContentState, .body, DeviceConsole, .body, IssueText, Portions, .body, .body (+11 more)

### Community 4 - "Mengen und Editor-Zutaten"
Cohesion: 0.06
Nodes (18): SubstituteRow, .body, .body, CookingAnswers, Amount, measured, toTaste, MeasureUnit (+10 more)

### Community 5 - "Live Activity und Alarme"
Cohesion: 0.05
Nodes (22): ActivityKit, AlarmKit, ContentState, CookingActivityAttributes, CookingAlarmData, CookingLiveActivity, ClaudeKitchenWidgets, .body (+14 more)

### Community 6 - "Siri und Schritt-Intents"
Cohesion: 0.06
Nodes (30): CookingIntentBridge, CookingIntentCommand, currentStep, next, pauseTimer, previous, remainingTime, startTimer (+22 more)

### Community 7 - "Einkauf und Vorrat UI"
Cohesion: 0.09
Nodes (14): PantryView, .body, PantryEntry, .id, PlannedRecipe, .id, ShoppingModel, .pantryItems (+6 more)

### Community 8 - "Einstellungen, Schlüssel, Sprachprotokoll"
Cohesion: 0.07
Nodes (16): APIKeyStore, .hasKey, .query, SettingsView, .body, VoiceLogRow, .body, VoiceLogView (+8 more)

### Community 9 - "Lebensmittel und Nährwert-Tests"
Cohesion: 0.07
Nodes (13): BoilRequirement, Food, .searchTerm, FoodGroup, FoodRole, aromatic, base, fat (+5 more)

### Community 10 - "Spracheingabe und Sprachausgabe"
Cohesion: 0.07
Nodes (7): Speaker, AudioFeed, SpeechListener, .isMuted, AVFoundation, Speech, Synchronization

### Community 11 - "Zutaten-Zuordnung und Rezeptqualität"
Cohesion: 0.08
Nodes (7): FoodCatalog, .matcher, FoodMatcher, Key, Recipe, TextFold, RecipeQualityTests

### Community 12 - "Essensplan und Vorrat"
Cohesion: 0.11
Nodes (10): .addableFoods, .hasChecked, ShoppingStore, .file, Entry, .id, MealPlan, ShoppingState (+2 more)

### Community 13 - "Plan: Entscheidungen und Meilensteine"
Cohesion: 0.08
Nodes (15): PLAN.md Aufbauplan, Barrierefreiheit, Ersatzzutaten, M0 Repo-Geruest, M12 Sprachprotokoll Editor Ersatzlisten, M13 Parallele Timer, M2 Bibliothek und Rezeptdetail, M3 Kochmodus (+7 more)

### Community 14 - "TestFlight-Workflow"
Cohesion: 0.06
Nodes (38): environment, if, outputs, runs-on, steps, timeout-minutes, concurrency, cancel-in-progress (+30 more)

### Community 15 - "Recipe"
Cohesion: 0.12
Nodes (14): .displayName, Datenmodell KitchenCore, M1 KitchenCore Modelle, Skalierung und Plausibilitaet, Rezept-JSON-Schema, Accessory, basket, steamer (+6 more)

### Community 16 - "Python-Werkzeuge"
Cohesion: 0.10
Nodes (13): gradient(), herb_glow(), main(), pot(), norm(), build_prompt(), generate(), http() (+5 more)

### Community 17 - "Recipe Editing"
Cohesion: 0.08
Nodes (15): DeviceProfile, .quickDurations, .quickTemperatures, .suggestedCelsius, .suggestedDuration, .suggestedSpeed, EditingProblem, emptyStep (+7 more)

### Community 18 - "Cooking View"
Cohesion: 0.11
Nodes (18): CookingChrome, .session, CookingControls, CookingView, .body, .controls, .session, .stepArea (+10 more)

### Community 19 - "Recipe Detail View"
Cohesion: 0.14
Nodes (22): View, ChangeRow, .body, .offer, IngredientList, .body, NutritionComparison, .body (+14 more)

### Community 20 - "Voice Command"
Cohesion: 0.10
Nodes (13): .intent, VoiceCommand, next, pauseTimer, previous, question, remainingTime, repeatStep (+5 more)

### Community 21 - "Claude Recipe Import"
Cohesion: 0.11
Nodes (10): APIError, Block, ClaudeRecipeImport, .schema, CodingKeys, content, error, stopReason (+2 more)

### Community 22 - "Pantry"
Cohesion: 0.08
Nodes (9): FoodPicker, .body, .filtered, PantryRow, .body, PantryItem, Stock, grams (+1 more)

### Community 23 - "Shopping List"
Cohesion: 0.13
Nodes (11): .openItems, Array, Demand, Item, .id, Need, Quantity, grams (+3 more)

### Community 24 - "Step Editor View"
Cohesion: 0.10
Nodes (19): DeviceSection, .duration, .durationBinding, .hasDuration, .heat, .heatMode, .rotation, .rotationMode (+11 more)

### Community 25 - "Food Catalog"
Cohesion: 0.07
Nodes (23): CatalogIssue, assessedWithoutSource, duplicateFood, duplicateGroup, duplicateSource, duplicateTarget, effectContradictsDirection, implausibleNutrients (+15 more)

### Community 27 - "Recipe Editor View"
Cohesion: 0.11
Nodes (16): CheckSection, .body, EditorRoute, ingredient, step, IngredientSection, .body, PasteIngredientsView (+8 more)

### Community 28 - "CI-Workflow"
Cohesion: 0.08
Nodes (27): runs-on, steps, timeout-minutes, concurrency, cancel-in-progress, group, SWIFT_VERSION, jobs (+19 more)

### Community 29 - "Recipe Rewriter"
Cohesion: 0.16
Nodes (5): steps, Recipe, RecipeChange, RecipeRewrite, SkippedSwap

### Community 30 - "Rewrite Rules"
Cohesion: 0.12
Nodes (11): Criterion, carbohydrate, energyDensity, groupRank, sodium, FoodGroup.Direction, .rank, GoalNote (+3 more)

### Community 31 - "Recipe Image Band"
Cohesion: 0.13
Nodes (14): .body, Drift, DriftingRow, .body, .drifting, .period, RecipeImageBand, .body (+6 more)

### Community 32 - "Food"
Cohesion: 0.09
Nodes (23): Severity, error, warning, Certainty, high, low, moderate, notRated (+15 more)

### Community 33 - "Claude Recipe Improvement"
Cohesion: 0.14
Nodes (15): Answer, Ingredient, Note, RecipeFeedback, .isActionable, .promptText, RecipeImprovement, Step (+7 more)

### Community 35 - "Recipe (2)"
Cohesion: 0.07
Nodes (27): CodingKeys, accessory, authenticityChecks, baseServings, eaten, food, foodChosenByHand, freshPot (+19 more)

### Community 36 - "Recipe Editor Model"
Cohesion: 0.16
Nodes (6): .body, RecipeEditorModel, .canSave, .cleanedRecipe, .hasChanges, .recipe

### Community 37 - "Recipe Detail Model"
Cohesion: 0.11
Nodes (13): RecipeDetailModel, .canDecrease, .canIncrease, .displayed, .goal, .goals, .ingredients, .warnings (+5 more)

### Community 38 - "System Alarm Scheduler"
Cohesion: 0.14
Nodes (9): NoAlarmScheduler, SystemAlarmScheduler, AlarmKit Timer, Live Activity Schritt, Parallele Timer, SideTimer und TimerPlace, AlarmScheduler, .alarm (+1 more)

### Community 39 - "Ingredient Editor View"
Cohesion: 0.14
Nodes (15): AmountSection, .body, .quantity, .toTaste, .unit, Binding, .orEmpty, FoodChoiceList (+7 more)

### Community 40 - "Evidence"
Cohesion: 0.14
Nodes (13): EffectEstimate, .isSignificant, IntakeTarget, Measure, grams, servings, Outcome, allCauseMortality (+5 more)

### Community 41 - "Cooking Session"
Cohesion: 0.13
Nodes (8): CookingSession, .currentStep, .isFirstStep, .isLastStep, .isTimerFromOtherStep, .isTimerRunning, .scaledIngredients, TimerAlarmTests

### Community 44 - "Glyph"
Cohesion: 0.11
Nodes (10): Glyph, .body, Motion, Palette, WarmBackground, .body, .hero, .heroMeta (+2 more)

### Community 46 - "Improve Recipe Model"
Cohesion: 0.12
Nodes (7): ImproveRecipeModel, .isWorking, Phase, failed, ready, review, working

### Community 47 - "Recipe Draft"
Cohesion: 0.21
Nodes (9): Ingredient, RecipeDraft, RecipeDraftError, ingredientIndexOutOfRange, unknownAccessory, unknownProgram, unknownUnit, Setting (+1 more)

### Community 48 - "Rewrite Rules (2)"
Cohesion: 0.20
Nodes (5): LoadError, missingResource, unsupportedSchemaVersion, RewriteGoal, RewriteRules

### Community 49 - "Claude Client"
Cohesion: 0.15
Nodes (6): ClaudeClient, ClientError, insecureLink, missingKey, network, page

### Community 50 - "Import Recipe Model"
Cohesion: 0.14
Nodes (7): ImportRecipeModel, .canConvert, .canSave, .linkIsInsecure, .linkURL, .trimmedText, .primaryAction

### Community 51 - "Recipe Origin"
Cohesion: 0.12
Nodes (13): .displayName, Cuisine, china, europe, georgia, india, japanKorea, mexicoPeru (+5 more)

### Community 52 - "Recipe Library View"
Cohesion: 0.17
Nodes (7): CuisineFilter, .body, ImproveRequest, RatingRequest, .id, RecipeLibraryView, .body

### Community 53 - "Food (2)"
Cohesion: 0.10
Nodes (20): CodingKeys, aisle, aliases, certainty, direction, effects, gramsPerUnit, group (+12 more)

### Community 54 - "Nutrition"
Cohesion: 0.17
Nodes (4): FoodCatalog, Nutrients, .isPlausible, NutritionFacts

### Community 55 - "project"
Cohesion: 0.11
Nodes (19): ASSETCATALOG_COMPILER_APPICON_NAME, ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME, CURRENT_PROJECT_VERSION, GENERATE_INFOPLIST_FILE, INFOPLIST_KEY_CFBundleDisplayName, INFOPLIST_KEY_ITSAppUsesNonExemptEncryption, INFOPLIST_KEY_NSSupportsLiveActivities, INFOPLIST_KEY_UIApplicationSceneManifest_Generation (+11 more)

### Community 56 - "Food Catalog (2)"
Cohesion: 0.15
Nodes (5): EvidenceSource, FoodCatalog, LoadError, missingResource, unsupportedSchemaVersion

### Community 57 - "Cooking Session (2)"
Cohesion: 0.12
Nodes (15): CookingAction, goToStep, next, pauseTimer, previous, resetTimer, setServings, startTimer (+7 more)

### Community 58 - "Recipe Library Model"
Cohesion: 0.25
Nodes (5): EditorRequest, .id, RecipeLibraryModel, .bundled, .recipes

### Community 59 - "Voice Mode Model"
Cohesion: 0.20
Nodes (3): Exchange, VoiceModeModel, .isOn

### Community 60 - "Projektregeln"
Cohesion: 0.12
Nodes (15): CLAUDE.md Projektanweisungen, Skill app-architecture, CI und TestFlight Workflows, Cloud-Sessions auf Linux, Geraetewerte nur ueber DeviceProfile, Glas nur auf Bedienebene, iOS 27 only, keine Fallbacks, Kein eingechecktes xcodeproj (+7 more)

### Community 62 - "Rezept-Prompt und Regeln"
Cohesion: 0.13
Nodes (15): Sprachregel Deutsch ohne Gedankenstriche, Gauntlet-Loop, Geraete-Pruefliste iPhone 18, M10 Rezeptbestand, Rezeptbestand authentisch, Prompt Rezeptbestand erweitern, Auftrag 10 Rezepte pro Kueche, Neun Kuechen und Cuisine (+7 more)

### Community 63 - "JSONValue"
Cohesion: 0.13
Nodes (9): JSONValue, array, bool, integer, .members, null, number, object (+1 more)

### Community 64 - "Rewrite Rules (3)"
Cohesion: 0.12
Nodes (17): CodingKeys, criterion, extends, extraSeconds, extraWaterPerGram, from, id, notes (+9 more)

### Community 65 - "File Recipe Store"
Cohesion: 0.20
Nodes (3): FileRecipeStore, .directory, RecipeStore

### Community 66 - "Import Recipe View"
Cohesion: 0.16
Nodes (6): EditingForm, .body, ImportPreview, ImportRecipeView, .body, .content

### Community 68 - "Shopping Text"
Cohesion: 0.21
Nodes (3): ShoppingText, ShoppingRow, .body

### Community 69 - "Health Advisor"
Cohesion: 0.23
Nodes (6): ChangeDetail, HealthAdvisor, .goals, NoteDetail, RecipeVariant, .recipe

### Community 71 - "Claude Recipe Import (2)"
Cohesion: 0.19
Nodes (6): ResponseError, api, http, missingRecipe, refusal, truncated

### Community 72 - "Recipe Search Tests"
Cohesion: 0.18
Nodes (3): Recipe, RecipeLibrary, RecipeOriginTests

### Community 73 - "Health Goals"
Cohesion: 0.22
Nodes (3): HealthGoals, .vegetarianByDefault, .swap

### Community 74 - "Device Setting"
Cohesion: 0.14
Nodes (12): Program, knead, manual, sousVide, steam, weigh, yogurt, .schema (+4 more)

### Community 75 - "Aisle"
Cohesion: 0.16
Nodes (9): Aisle, chilled, dryGoods, frozen, other, produce, .rank, spices (+1 more)

### Community 76 - "Speech Listener"
Cohesion: 0.15
Nodes (10): Failure, denied, noWritableAccount, Failure, germanUnsupported, microphoneDenied, noAudioFormat, LoadError (+2 more)

### Community 77 - "Rewrite Rules (4)"
Cohesion: 0.15
Nodes (13): RewriteRuleIssue, duplicateGoal, duplicateRule, emptyNote, inheritedRuleWorsens, invalidRule, missingNutrients, notImproving (+5 more)

### Community 78 - "Recipe Photo"
Cohesion: 0.20
Nodes (6): PhotoMetrics, RecipePhoto, .body, .placeholder, .body, UIKit

### Community 79 - "Claude Recipe Improvement (2)"
Cohesion: 0.17
Nodes (11): ImprovementError, catalogIssues, deviceIssues, draft, duplicateIngredientID, duplicateStepID, emptySummary, markedVerified (+3 more)

### Community 81 - "Improve Recipe Sheet"
Cohesion: 0.27
Nodes (4): ImproveRecipeSheet, .body, .feedbackSection, .toolbar

### Community 82 - "Recipe Search"
Cohesion: 0.20
Nodes (4): .cuisineName, .own, .visibleRecipes, RecipeSearch

### Community 83 - "TestFlight-Doku"
Cohesion: 0.25
Nodes (9): TestFlight einrichten, App Store Connect Einrichtung, Build-Nummern Lauf.Versuch, Bundle-ID com.tomren.claudekitchen, TestFlight Fehlerbehebung, GitHub Environment testflight, Schluessel widerrufen, testflight.yml Workflow (+1 more)

### Community 84 - "PLAN"
Cohesion: 0.24
Nodes (5): Einkauf und Vorrat, Direkte Geraetesteuerung ueber WLAN, M11 Einkauf und Vorrat, Einkaufs-Agent statt REWE-API, AgentBrief

### Community 86 - "project (2)"
Cohesion: 0.20
Nodes (9): configFiles, Debug, Release, path, name, packages, KitchenCore, settings (+1 more)

### Community 87 - "project (3)"
Cohesion: 0.22
Nodes (10): info, info, path, properties, NSExtensionPointIdentifier, NSAlarmKitUsageDescription, NSExtension, NSMicrophoneUsageDescription (+2 more)

### Community 88 - "Food Catalog (3)"
Cohesion: 0.20
Nodes (9): CodingKeys, foods, groups, schemaVersion, sources, targets, CodingKeys, grams (+1 more)

### Community 90 - "Cooking Status"
Cohesion: 0.20
Nodes (6): CookingStatus, Timer, finished, none, paused, running

### Community 91 - "Step Editor View (2)"
Cohesion: 0.31
Nodes (4): IngredientPicker, .body, StepEditorView, .body

### Community 93 - "project (4)"
Cohesion: 0.25
Nodes (8): dependencies, platform, scheme, settings, sources, type, target, ClaudeKitchen

### Community 94 - "Cooking Status Tests"
Cohesion: 0.29
Nodes (3): .remainingAnswer, .stepAnswer, CookingStatusTests

### Community 95 - "Route"
Cohesion: 0.25
Nodes (3): Route, cooking, recipe

### Community 96 - "project (5)"
Cohesion: 0.29
Nodes (7): dependencies, platform, settings, sources, type, package, ClaudeKitchenWidgets

### Community 98 - "project (6)"
Cohesion: 0.33
Nodes (6): iOS, options, bundleIdPrefix, createIntermediateGroups, deploymentTarget, developmentLanguage

### Community 100 - "Import Recipe Model (2)"
Cohesion: 0.33
Nodes (5): Phase, editing, failed, preview, working

### Community 104 - "Voice Mode Model (2)"
Cohesion: 0.33
Nodes (6): State, answering, failed, listening, off, starting

### Community 105 - "Device Setting (2)"
Cohesion: 0.33
Nodes (6): CodingKeys, heat, program, reverse, seconds, speed

### Community 107 - "PLAN (2)"
Cohesion: 0.40
Nodes (5): Evidenz-Datenbank, Gesund umschreiben, HealthyVariant, Lebensmittelkatalog, Gesundheitsziele

### Community 108 - "Shopping List (2)"
Cohesion: 0.40
Nodes (5): Reason, belowMinimum, needed, runningLow, unknownStock

### Community 109 - "Timer Alarm"
Cohesion: 0.40
Nodes (4): Phase, finished, paused, running

## Knowledge Gaps
- **418 isolated node(s):** `next`, `previous`, `startTimer`, `pauseTimer`, `currentStep` (+413 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 834 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **19 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Foundation` connect `App-Modelle und Dienste` to `Startseite und Kochprotokoll`, `Geräteprofil und Rezeptregeln`, `Kochmodus-Oberfläche`, `Mengen und Editor-Zutaten`, `Einstellungen, Schlüssel, Sprachprotokoll`, `Lebensmittel und Nährwert-Tests`, `Zutaten-Zuordnung und Rezeptqualität`, `Essensplan und Vorrat`, `Recipe`, `Recipe Editing`, `Voice Command`, `Claude Recipe Import`, `Shopping List`, `Food Catalog`, `Recipe Rewriter`, `Rewrite Rules`, `Claude Recipe Improvement`, `System Alarm Scheduler`, `Evidence`, `Recipe Draft`, `Recipe Origin`, `Nutrition`, `Cooking Session (2)`, `JSONValue`, `File Recipe Store`, `Health Advisor`, `Recipe Search Tests`, `Device Setting`, `Aisle`, `Recipe Search`, `PLAN`, `Identifier`, `Cooking Status`?**
  _High betweenness centrality (0.086) - this node is a cross-community bridge._
- **Are the 32 inferred relationships involving `CookingSession` (e.g. with `.page()` and `.state()`) actually correct?**
  _`CookingSession` has 32 INFERRED edges - model-reasoned connections that need verification._
- **What connects `next`, `previous`, `startTimer` to the rest of the system?**
  _418 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `App-Modelle und Dienste` be split into smaller, more focused modules?**
  _Cohesion score 0.057902973395931145 - nodes in this community are weakly interconnected._
- **Why does `View` connect `Recipe Detail View` to `Startseite und Kochprotokoll`, `Kochmodus-Oberfläche`, `Mengen und Editor-Zutaten`, `Live Activity und Alarme`, `Einkauf und Vorrat UI`, `Einstellungen, Schlüssel, Sprachprotokoll`, `Cooking View`, `Pantry`, `Step Editor View`, `Recipe Editor View`, `Recipe Image Band`, `Recipe Detail Model`, `Ingredient Editor View`, `Glyph`, `Cooking Screen Model`, `Recipe Library View`, `Recipe Library Model`, `Import Recipe View`, `Shopping Text`, `Recipe Photo`, `Improve Recipe Sheet`, `Step Editor View (2)`, `Improve Recipe Sheet (2)`, `Cook Rating Sheet`, `Recipe Detail View (2)`?**
  _High betweenness centrality (0.073) - this node is a cross-community bridge._
- **Should `Startseite und Kochprotokoll` be split into smaller, more focused modules?**
  _Cohesion score 0.06713286713286713 - nodes in this community are weakly interconnected._
- **Why does `KitchenCore` connect `App-Modelle und Dienste` to `Startseite und Kochprotokoll`, `Kochmodus-Oberfläche`, `Mengen und Editor-Zutaten`, `Live Activity und Alarme`, `Einstellungen, Schlüssel, Sprachprotokoll`, `Cooking View`, `Recipe Detail View`, `Pantry`, `Step Editor View`, `Recipe Editor View`, `Recipe Image Band`, `Ingredient Editor View`, `Glyph`, `Recipe Origin`, `Recipe Library View`, `Import Recipe View`, `Shopping Text`, `Recipe Photo`, `Route`?**
  _High betweenness centrality (0.072) - this node is a cross-community bridge._