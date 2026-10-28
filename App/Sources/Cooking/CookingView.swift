import KitchenCore
import SwiftUI
import UIKit

/// Full-screen guided cook: one step at a time, device console and timer in glass at the bottom.
struct CookingView: View {
    @State private var model: CookingScreenModel
    @State private var voice: VoiceModeModel
    @State private var explaining: SpiceGuideRequest?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let onFinish: @MainActor () -> Void

    /// `recipe` and `servings` seed the screen model once.
    init(
        recipe: Recipe, servings: Int, alarms: any AlarmScheduler = SystemAlarmScheduler.shared,
        onFinish: @escaping @MainActor () -> Void
    ) {
        let model = CookingScreenModel(recipe: recipe, servings: servings, alarms: alarms)
        self.model = model
        self.voice = VoiceModeModel(cooking: model)
        self.onFinish = onFinish
    }

    private var session: CookingSession { model.session }

    var body: some View {
        if session.recipe.steps.isEmpty {
            ContentUnavailableView(
                "Keine Schritte", systemImage: "list.bullet", description: Text("Dieses Rezept hat keine Schritte."))
        } else {
            // One view tree for every size class: only the position of the controls changes, so resizing an iPad
            // window never runs the lifecycle (and never ends the cook).
            stepArea
                .safeAreaBar(edge: .bottom) {
                    if horizontalSizeClass != .regular {
                        controls
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                }
                .safeAreaInset(edge: .trailing, spacing: 0) {
                    if horizontalSizeClass == .regular {
                        // iPad: console and timer always in view next to the step, about 40 % of the width.
                        controls
                            .containerRelativeFrame(.horizontal) { width, _ in min(400, width * 0.4) }
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .padding(16)
                    }
                }
                .safeAreaBar(edge: .top) {
                    VoiceStatus(voice: voice)
                        .padding(.horizontal, 16)
                        .animation(Motion.voiceStatus, value: voice.state)
                        .animation(Motion.voiceStatus, value: voice.exchange)
                }
                .modifier(CookingChrome(model: model, voice: voice))
                .sheet(item: $explaining) { request in
                    SpiceGuideSheet(name: request.name, entry: request.entry)
                }
        }
    }

    private var stepArea: some View {
        VStack(spacing: 0) {
            ProgressDots(count: session.recipe.steps.count, current: session.stepIndex)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            if reduceMotion {
                // Reduce Motion: no sideways travel, steps cross-fade; changes go through the buttons.
                page(for: session.stepIndex)
                    .id(session.stepIndex)
                    .transition(.opacity)
                    .animation(Motion.stepCrossFade, value: session.stepIndex)
            } else {
                TabView(selection: stepSelection) {
                    ForEach(Array(session.recipe.steps.enumerated()), id: \.element.id) { index, step in
                        Tab(value: step.id) { page(for: index) }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
    }

    private func page(for index: Int) -> some View {
        let step = session.recipe.steps[index]
        return StepPage(
            number: index + 1, total: session.recipe.steps.count, step: step,
            ingredients: session.ingredients(for: step).map {
                ($0.ingredient.id, $0.ingredient.name, AmountFormatter.string(for: $0.amount))
            },
            explain: { id in
                guard let ingredient = session.recipe.ingredients.first(where: { $0.id == id }),
                    let entry = SpiceGuide.shared?.entry(for: ingredient.food)
                else { return nil }
                return { explaining = SpiceGuideRequest(name: ingredient.name, entry: entry) }
            }
        )
    }

    private var controls: some View {
        CookingControls(
            parts: session.currentStep?.setting.map(SettingFormatter.labeledParts(of:)) ?? [],
            timer: model.remaining.map { remaining in
                TimerDisplay(
                    clock: SettingFormatter.clock(remaining), seconds: Int(remaining.components.seconds),
                    isRunning: session.isTimerRunning, isFinished: session.timer == .finished,
                    fromStep: session.isTimerFromOtherStep ? session.timerStepIndex + 1 : nil)
            },
            isFirstStep: session.isFirstStep, isLastStep: session.isLastStep,
            accent: Palette.accent(for: session.recipe.variantOf ?? session.recipe.id),
            onPrevious: { withAnimation(Motion.stepAdvance) { model.previous() } },
            onNext: {
                if session.isLastStep {
                    onFinish()
                } else {
                    withAnimation(Motion.stepAdvance) { model.next() }
                }
            },
            onStart: model.startTimer, onPause: model.pauseTimer, onReset: model.resetTimer)
    }

    /// Swiping the pager goes through the session like the buttons do.
    private var stepSelection: Binding<StepID> {
        Binding(
            get: { session.currentStep?.id ?? "" },
            set: { id in
                if let index = session.recipe.steps.firstIndex(where: { $0.id == id }) {
                    model.goToStep(index)
                }
            }
        )
    }
}

/// Everything the cooking screen needs regardless of layout: background, title, clock, idle timer, feedback.
private struct CookingChrome: ViewModifier {
    let model: CookingScreenModel
    let voice: VoiceModeModel
    @Environment(\.scenePhase) private var scenePhase
    /// Listening is on by default; switching it off sticks for later cooks.
    @AppStorage("voiceModeOn") private var voiceModeOn = true

    private var session: CookingSession { model.session }

    func body(content: Content) -> some View {
        content
            .background { WarmBackground(tint: Palette.accent(for: session.recipe.variantOf ?? session.recipe.id)) }
            .navigationTitle(session.recipe.name)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(
                        voice.isOn ? "Zuhören beenden" : "Zuhören",
                        systemImage: voice.isOn ? "mic.fill" : "mic.slash"
                    ) {
                        voice.toggle()
                        voiceModeOn = voice.isOn
                    }
                    .symbolEffect(.pulse, isActive: voice.state == .listening)
                }
            }
            .task { await model.runClock() }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    model.tick()
                    if voiceModeOn { voice.start() }
                case .background:
                    // No microphone in the background; listening resumes when the cook comes back.
                    voice.stop()
                default:
                    break
                }
            }
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
                model.begin()
                if voiceModeOn { voice.start() }
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
                voice.stop()
                model.end()
            }
            .sensoryFeedback(.success, trigger: session.finishedTimerCount)
            .sensoryFeedback(.selection, trigger: session.stepIndex)
    }
}

/// What the timer row shows, as plain values.
struct TimerDisplay: Equatable {
    var clock: String
    var seconds: Int
    var isRunning: Bool
    var isFinished: Bool
    /// Number of the step the timer belongs to, when that is not the current step.
    var fromStep: Int?
}

private struct ProgressDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(color(for: index))
                    .frame(height: 5)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Schritt \(current + 1) von \(count)")
    }

    private func color(for index: Int) -> Color {
        index < current ? Palette.herb : index == current ? Palette.accent : Palette.muted.opacity(0.3)
    }
}

/// One step as content: large text on a solid card, no glass.
private struct StepPage: View {
    let number: Int
    let total: Int
    let step: Step
    let ingredients: [(id: IngredientID, name: String, amount: String)]
    /// How to open the spice guide for an ingredient, nil when the guide has nothing on it.
    let explain: (IngredientID) -> (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Schritt \(number) von \(total)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.muted)
                    Spacer()
                    Text(step.phase.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(Palette.accent)
                }
                Text(step.text)
                    .font(.title.weight(.medium))
                    .fontDesign(.serif)
                    .foregroundStyle(Palette.ink)
                if let note = step.note {
                    Text(note)
                        .font(.body)
                        .foregroundStyle(Palette.muted)
                }
                if let accessory = step.accessory {
                    Label(accessory.displayName, systemImage: "square.stack.3d.up")
                        .font(.headline)
                        .foregroundStyle(Palette.cool)
                }
                ForEach(ingredients, id: \.id) { item in
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.name)
                        if let open = explain(item.id) {
                            // Large target for wet hands: the button is the full 44 pt, the icon stays small.
                            Button("Was ist \(item.name)?", systemImage: "info.circle", action: open)
                                .labelStyle(.iconOnly)
                                .foregroundStyle(Palette.cool)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(.rect)
                                .buttonStyle(.borderless)
                        }
                        Spacer()
                        Text(item.amount)
                            .monospacedDigit()
                            .foregroundStyle(Palette.muted)
                    }
                    .font(.title3)
                    .foregroundStyle(Palette.ink)
                    .accessibilityElement(children: .contain)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: .rect(cornerRadius: 24))
            .padding(16)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// Bottom chrome: device console, timer and navigation, sharing one glass sampling region.
private struct CookingControls: View {
    let parts: [SettingFormatter.Part]
    let timer: TimerDisplay?
    let isFirstStep: Bool
    let isLastStep: Bool
    let accent: Color
    let onPrevious: @MainActor () -> Void
    let onNext: @MainActor () -> Void
    let onStart: @MainActor () -> Void
    let onPause: @MainActor () -> Void
    let onReset: @MainActor () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 12) {
                if !parts.isEmpty {
                    DeviceConsole(parts: parts)
                }
                if let timer {
                    TimerControl(display: timer, onStart: onStart, onPause: onPause, onReset: onReset)
                }
                HStack(spacing: 12) {
                    Button("Zurück", systemImage: "chevron.left", action: onPrevious)
                        .buttonStyle(.glass)
                        .disabled(isFirstStep)
                    Button(action: onNext) {
                        Label(isLastStep ? "Fertig" : "Weiter", systemImage: isLastStep ? "checkmark" : "chevron.right")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(Palette.cream)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(accent)
                }
                .controlSize(.extraLarge)
                .font(.headline)
            }
        }
    }
}

/// What to set on the device for this step, one glass tile per value.
private struct DeviceConsole: View {
    let parts: [SettingFormatter.Part]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility text sizes the tiles go two per row, so values stay legible without the console
        // pushing the step text off screen.
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: dynamicTypeSize.isAccessibilitySize ? 2 : max(parts.count, 1))
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(parts, id: \.kind) { part in
                VStack(spacing: 2) {
                    Text(part.label.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(Palette.ink)
                    Text(part.value)
                        .font(.title2.weight(.semibold))
                        .fontDesign(.serif)
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: 64)
                .padding(.horizontal, 8)
                .glassEffect(.regular.tint(tint(for: part.kind).opacity(0.25)), in: .rect(cornerRadius: 18))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(part.text)
            }
        }
    }

    private func tint(for kind: SettingFormatter.Part.Kind) -> Color {
        switch kind {
        case .program: Palette.cool
        case .temperature: Palette.accent
        case .rotation: Palette.herb
        case .duration: Palette.muted
        }
    }
}

/// The countdown in one glass row. The buttons inside are plain, so there is no glass on glass.
private struct TimerControl: View {
    let display: TimerDisplay
    let onStart: @MainActor () -> Void
    let onPause: @MainActor () -> Void
    let onReset: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                if let step = display.fromStep {
                    Text("Timer aus Schritt \(step)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.muted)
                }
                Text(display.clock)
                    .font(.system(.largeTitle, design: .serif, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(Motion.timerTick, value: display.seconds)
                    .foregroundStyle(display.isFinished ? Palette.accent : Palette.ink)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(display.isFinished ? "Timer abgelaufen" : "Restzeit \(display.clock)")
            Spacer()
            if display.isRunning {
                timerButton("Pause", systemImage: "pause.fill", action: onPause)
            } else if !display.isFinished {
                timerButton("Start", systemImage: "play.fill", action: onStart)
            }
            timerButton("Zurücksetzen", systemImage: "arrow.counterclockwise", action: onReset)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private func timerButton(_ title: String, systemImage: String, action: @escaping @MainActor () -> Void) -> some View
    {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .font(.title)
            .frame(minWidth: 56, minHeight: 56)
            .contentShape(.rect)
            .buttonStyle(.borderless)
    }
}

#Preview {
    if let recipe = Recipe.fixtures.first {
        NavigationStack {
            CookingView(recipe: recipe, servings: 3, alarms: NoAlarmScheduler()) {}
        }
    }
}

/// What the voice mode heard and answered, in a glass pill above the step. Hidden while the mode is off.
private struct VoiceStatus: View {
    let voice: VoiceModeModel

    var body: some View {
        if let text {
            VStack(alignment: .leading, spacing: 2) {
                if let heard = voice.exchange?.heard, voice.state != .starting {
                    Text("„\(heard)“")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(text)
                    .font(.subheadline)
                    .lineLimit(3)
                if voice.exchange?.isUnchecked == true, voice.state != .starting {
                    Label("KI-Antwort, ungeprüft", systemImage: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
            .transition(.opacity)
            .accessibilityElement(children: .combine)
        }
    }

    private var text: String? {
        switch voice.state {
        case .off: nil
        case .starting: "Zuhören wird vorbereitet …"
        case .failed(let message): message
        case .listening, .answering:
            voice.exchange?.reply ?? "Ich höre zu. Sag zum Beispiel „weiter“ oder „Omni, …“ für eine Frage."
        }
    }
}
