import AVFoundation

/// Speaks German answers with the best installed German voice and waits until each one is done.
@MainActor
final class Speaker: NSObject {
    /// Created with the first answer, so a cook without voice mode never sets up speech.
    private var synthesizer: AVSpeechSynthesizer?
    /// The utterance being spoken and who waits for it. A late callback for an earlier utterance is ignored.
    private var pending: (utterance: ObjectIdentifier, continuation: CheckedContinuation<Void, Never>)?

    private static let voice: AVSpeechSynthesisVoice? =
        AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language == "de-DE" }
        .max { $0.quality.rawValue < $1.quality.rawValue }
        ?? AVSpeechSynthesisVoice(language: "de-DE")

    /// Returns once `text` has been spoken or `stop()` cut it off.
    func say(_ text: String) async {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice
        let synthesizer = self.synthesizer ?? AVSpeechSynthesizer()
        if self.synthesizer == nil {
            synthesizer.delegate = self
            self.synthesizer = synthesizer
        }
        await withCheckedContinuation { continuation in
            pending = (ObjectIdentifier(utterance), continuation)
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        if let synthesizer, synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        pending?.continuation.resume()
        pending = nil
    }

    fileprivate func finish(_ utterance: ObjectIdentifier) {
        guard pending?.utterance == utterance else { return }
        pending?.continuation.resume()
        pending = nil
    }
}

extension Speaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finish(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finish(id) }
    }
}
