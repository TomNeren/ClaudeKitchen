import Foundation
import KitchenCore
import Observation

/// Hands-free cooking: listens while the cooking mode is open, carries out short commands, answers substitutions
/// from the recipe and free questions after "Omni" with the on-device model.
@MainActor @Observable
final class VoiceModeModel {
    enum State: Equatable {
        case off
        case starting
        case listening
        case answering
        case failed(String)
    }

    /// The last thing heard and the reply to it, for the status pill.
    struct Exchange: Equatable {
        var heard: String
        var reply: String
        /// From the language model, not from the recipe.
        var isUnchecked: Bool
    }

    private(set) var state: State = .off
    private(set) var exchange: Exchange?

    private let cooking: CookingScreenModel
    private let device: DeviceProfile
    private let listener = SpeechListener()
    private let speaker = Speaker()
    private let log: VoiceLogStore
    private var loop: Task<Void, Never>?
    /// The last shutdown of the listener; a new start waits for it.
    private var shutdown: Task<Void, Never>?
    /// Restarts after audio was taken away, since the last sentence heard. Bounded, so a broken route cannot loop.
    private var restarts = 0
    private static let maxRestarts = 3

    init(cooking: CookingScreenModel, device: DeviceProfile = .omniCook, log: VoiceLogStore = .shared) {
        self.cooking = cooking
        self.device = device
        self.log = log
    }

    var isOn: Bool {
        switch state {
        case .off, .failed: false
        case .starting, .listening, .answering: true
        }
    }

    func toggle() {
        if isOn { stop() } else { start() }
    }

    func start() {
        guard !isOn else { return }
        state = .starting
        let previous = shutdown
        loop = Task {
            await previous?.value
            do {
                let sentences = try await listener.start()
                guard !Task.isCancelled else { return }
                state = .listening
                for await sentence in sentences {
                    restarts = 0
                    await handle(transcript: sentence)
                }
                guard !Task.isCancelled else { return }
                // Audio was taken away (a call, Siri, another route). Listen again once it is back; returning from
                // the background restarts as well.
                await listener.stop()
                state = .off
                guard restarts < Self.maxRestarts else { return }
                restarts += 1
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled { start() }
            } catch {
                guard !Task.isCancelled else { return }
                await listener.stop()
                state = .failed(Self.message(for: error))
            }
        }
    }

    func stop() {
        let running = loop
        running?.cancel()
        loop = nil
        speaker.stop()
        state = .off
        let listener = self.listener
        let previous = shutdown
        // After the loop: a start that was still loading the model must not leave the microphone on.
        shutdown = Task {
            await previous?.value
            await running?.value
            await listener.stop()
        }
    }

    /// One transcriber result can hold several sentences ("Weiter. Wie lange noch?"); each is handled on its own,
    /// so the second one does not make the first too long to count as a command.
    private func handle(transcript: String) async {
        for (sentence, command) in VoiceCommand.parseSentences(transcript) {
            await handle(sentence, command: command)
        }
    }

    private func handle(_ sentence: String, command: VoiceCommand?) async {
        guard state == .listening else { return }
        let heardAt = Date.now
        guard let command else {
            // Ignored sentences too: they show what the rules missed.
            record(.init(date: heardAt, heard: sentence, command: nil))
            return
        }
        state = .answering
        defer { if state == .answering { state = .listening } }
        let answer = await reply(to: command, sentence: sentence)
        record(.init(date: heardAt, heard: sentence, command: command.logName, reply: answer?.0))
        guard case (let reply, let isUnchecked)? = answer, !Task.isCancelled else { return }
        exchange = Exchange(heard: sentence, reply: reply, isUnchecked: isUnchecked)
        listener.isMuted = true
        await speaker.say(reply)
        listener.isMuted = false
    }

    /// What to say, and whether it comes from the language model. Nil to stay silent.
    private func reply(to command: VoiceCommand, sentence: String) async -> (String, Bool)? {
        if let intent = command.intent {
            return (await cooking.perform(intent), false)
        }
        let session = cooking.session
        switch command {
        case .stepIngredients:
            let items = session.currentStep.map(session.ingredients(for:)) ?? []
            return (CookingAnswers.ingredients(items), false)
        case .substitute(let name, let addressed):
            guard let ingredient = session.ingredient(named: name) else {
                // Without "Omni", "mir fehlt die Geduld" was conversation, not a question.
                return addressed ? ("Das steht nicht in diesem Rezept.", false) : nil
            }
            let substitutions = session.substitutions(for: ingredient)
            if !substitutions.isEmpty {
                return (CookingAnswers.substitutions(for: ingredient, substitutions), false)
            }
            guard CookingAssistant.isAvailable else {
                return ("Für \(ingredient.name) ist im Rezept kein Ersatz hinterlegt.", false)
            }
            let question = "Was kann ich statt \(ingredient.name) nehmen, und wie viel?"
            return (await CookingAssistant.answer(question, session: session, device: device), true)
        case .explain(let name, let addressed):
            if let found = SpiceGuide.shared?.entry(named: name, in: session, catalog: FoodCatalog.shared) {
                return (SpiceGuideText.spoken(name: found.name, entry: found.entry), false)
            }
            // Without "Omni" an unknown name was probably conversation; with it, the model gets the question.
            guard addressed else { return nil }
            guard CookingAssistant.isAvailable else {
                return ("Dazu steht nichts in der Gewürzkunde.", false)
            }
            let question = VoiceCommand.withoutWakeWord(sentence)
            return (await CookingAssistant.answer(question, session: session, device: device), true)
        case .question(let question):
            guard CookingAssistant.isAvailable else {
                return ("Freie Fragen gehen nur mit Apple Intelligence auf Deutsch.", false)
            }
            return (await CookingAssistant.answer(question, session: session, device: device), true)
        case .next, .previous, .repeatStep, .remainingTime, .startTimer, .pauseTimer:
            return nil
        }
    }

    /// One write per sentence, off the command path: the cook never waits for the log.
    private func record(_ entry: VoiceLog.Entry) {
        guard VoiceLogStore.isEnabled else { return }
        let log = self.log
        Task { await log.append(entry) }
    }

    private static func message(for error: any Error) -> String {
        switch error as? SpeechListener.Failure {
        case .microphoneDenied: "Kein Zugriff aufs Mikrofon. Erlaube ihn in den Einstellungen."
        case .germanUnsupported: "Deutsche Spracherkennung ist auf diesem Gerät nicht verfügbar."
        case .noAudioFormat, nil: "Zuhören ließ sich nicht starten."
        }
    }
}

extension VoiceCommand {
    /// The Siri command a spoken step or timer command stands for, so both say the same.
    fileprivate var intent: CookingIntentCommand? {
        switch self {
        case .next: .next
        case .previous: .previous
        case .repeatStep: .currentStep
        case .remainingTime: .remainingTime
        case .startTimer: .startTimer
        case .pauseTimer: .pauseTimer
        case .stepIngredients, .substitute, .explain, .question: nil
        }
    }
}
