import AVFoundation
import Speech
import Synchronization

/// Continuous German transcription from the microphone, on device. Yields each finished sentence.
@MainActor
final class SpeechListener {
    enum Failure: Error {
        case microphoneDenied
        case germanUnsupported
        case noAudioFormat
    }

    /// Created on start, so a listener that is never started costs nothing.
    private var engine: AVAudioEngine?
    private var analyzer: SpeechAnalyzer?
    private var feed: AudioFeed?
    private var results: Task<Void, Never>?
    private var sentences: AsyncStream<String>.Continuation?
    private var observers: [any NSObjectProtocol] = []

    /// While muted, microphone audio is dropped, so the app does not transcribe its own voice.
    var isMuted: Bool {
        get { feed?.muted.load(ordering: .relaxed) ?? false }
        set { feed?.muted.store(newValue, ordering: .relaxed) }
    }

    /// Asks for the microphone, loads the German model if needed and starts listening. The stream ends when
    /// `stop()` is called or audio is taken away (a call, Siri, another audio route).
    func start() async throws -> AsyncStream<String> {
        guard await AVAudioApplication.requestRecordPermission() else { throw Failure.microphoneDenied }
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "de_DE")) else {
            throw Failure.germanUnsupported
        }
        let transcriber = SpeechTranscriber(
            locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw Failure.noAudioFormat
        }

        let audioSession = AVAudioSession.sharedInstance()
        // Speaker, not the earpiece: the phone lies on the counter while the answers are spoken.
        try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let (inputs, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.start(inputSequence: inputs)
        self.analyzer = analyzer

        let engine = AVAudioEngine()
        self.engine = engine
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: inputFormat, to: format) else { throw Failure.noAudioFormat }
        let feed = AudioFeed(converter: converter, format: format, continuation: continuation)
        self.feed = feed
        try Self.installTap(on: input, format: inputFormat, feed: feed)
        engine.prepare()
        try engine.start()

        let (sentences, output) = AsyncStream<String>.makeStream()
        self.sentences = output
        observe(engine)
        results = Task {
            do {
                for try await result in transcriber.results where result.isFinal {
                    let sentence = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !sentence.isEmpty { output.yield(sentence) }
                }
            } catch {
                // The analyzer stopped (interruption, stop()); the stream ends below.
            }
            output.finish()
        }
        return sentences
    }

    func stop() async {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = []
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        sentences?.finish()
        sentences = nil
        feed?.finish()
        feed = nil
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        analyzer = nil
        results = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// An interruption or a changed audio route stops the engine; ending the stream lets the owner start again.
    private func observe(_ engine: AVAudioEngine) {
        let center = NotificationCenter.default
        let interruption = center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(), queue: .main
        ) { _ in
            MainActor.assumeIsolated { self.sentences?.finish() }
        }
        let configuration = center.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { _ in
            MainActor.assumeIsolated { self.sentences?.finish() }
        }
        observers = [interruption, configuration]
    }

    /// Built outside the main actor: the tap runs on the audio thread and must not inherit main-actor isolation.
    private nonisolated static func installTap(
        on input: AVAudioInputNode, format: AVAudioFormat, feed: AudioFeed
    ) throws {
        try input.installAudioTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            feed.feed(buffer)
        }
    }
}

/// Converts microphone buffers to the analyzer's format and hands them on. Used from the audio thread only, apart
/// from `muted`, which is atomic, and `finish()`, which runs after the tap is removed.
private final class AudioFeed: @unchecked Sendable {
    let muted = Atomic<Bool>(false)
    private let converter: AVAudioConverter
    private let format: AVAudioFormat
    private let continuation: AsyncStream<AnalyzerInput>.Continuation

    init(converter: AVAudioConverter, format: AVAudioFormat, continuation: AsyncStream<AnalyzerInput>.Continuation) {
        converter.primeMethod = .none
        self.converter = converter
        self.format = format
        self.continuation = continuation
    }

    func feed(_ tapBuffer: AVReadOnlyAudioPCMBuffer) {
        guard !muted.load(ordering: .relaxed) else { return }
        // The converter reads only mutable buffers, so the read-only tap buffer is copied first.
        let buffer = AVAudioPCMBuffer(copying: tapBuffer)
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return }
        var consumed = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            defer { consumed = true }
            inputStatus.pointee = consumed ? .noDataNow : .haveData
            return consumed ? nil : buffer
        }
        guard status != .error, output.frameLength > 0 else { return }
        continuation.yield(AnalyzerInput(buffer: output))
    }

    func finish() {
        continuation.finish()
    }
}
