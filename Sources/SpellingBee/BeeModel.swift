#if os(macOS)
import AppKit
import Foundation
import SpellingBeeCore

enum BeeScreen: Equatable {
    case home
    case playing
    case beeOver
}

@MainActor
final class BeeModel: ObservableObject {
    @Published var progress: BeeProgress
    @Published var screen: BeeScreen = .home
    @Published var session: BeeSession?
    @Published var word: WordEntry?
    @Published var typed = ""
    @Published var result: AnswerResult?
    @Published var showConfetti = false
    @Published var levelUp: Tier?
    @Published var steppedDown: Tier?
    @Published var showParentGate = false
    @Published var showParentScreen = false
    @Published var customProblem: String?
    @Published var hintShown: String?

    let speaker: Speaker
    private let store: ProgressStore
    private(set) var words: [WordEntry] = WordBank.builtIn
    private(set) var customCount = 0

    init() {
        speaker = Speaker()
        store = ProgressStore(directory: SupportFolder.url(named: SpellingBeeRelease.supportFolder))
        progress = store.load()
        store.ensureCustomWordsFile()
        reloadCustomWords()
    }

    var customWordsPath: String { store.customWordsURL.path }

    func reloadCustomWords() {
        let loaded = store.loadCustomWords()
        customCount = loaded.words.count
        customProblem = loaded.problem
        words = WordBank.merged(custom: loaded.words)
    }

    func persist() {
        if let session { progress = session.progress }
        try? store.save(progress)
    }

    func start(_ mode: PlayMode) {
        session = BeeSession(mode: mode, progress: progress, words: words)
        screen = .playing
        next()
    }

    func next() {
        guard var current = session else { return }
        result = nil
        typed = ""
        hintShown = nil
        steppedDown = nil
        word = current.nextWord()
        session = current
        if word == nil {
            finishBee()
            return
        }
        sayWord()
    }

    func sayWord() {
        guard let word else { return }
        speaker.say(word.word)
    }

    func saySlower() {
        guard let word else { return }
        speaker.say(word.word, slow: true)
    }

    func saySentence() {
        guard let word else { return }
        hintShown = word.blankedSentence
        speaker.say(word.sentence)
    }

    func sayDefinition() {
        guard let word else { return }
        hintShown = word.definition
        speaker.say(word.definition)
    }

    func submit() {
        guard result == nil, var current = session, let word else { return }
        guard !typed.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard let answer = current.submit(typed) else { return }
        session = current
        progress = current.progress
        result = answer
        if answer.correct {
            showConfetti = true
            speaker.say(["Yes!", "Correct!", "You got it!", "Great spelling!"].randomElement() ?? "Correct!")
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                self?.showConfetti = false
            }
        } else {
            speaker.say("Nice try. It's spelled")
            let spelled = word.word
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                self?.speaker.spell(spelled)
            }
        }
        switch answer.levelChange {
        case .levelUp(let tier):
            levelUp = tier
        case .stepDown(let tier):
            steppedDown = tier
        case nil:
            break
        }
        try? store.save(progress)
    }

    func continueAfterAnswer() {
        if session?.isOver == true {
            finishBee()
        } else {
            next()
        }
    }

    func finishBee() {
        speaker.stop()
        persist()
        screen = .beeOver
    }

    func goHome() {
        speaker.stop()
        persist()
        session = nil
        word = nil
        result = nil
        screen = .home
    }

    // MARK: Grown-ups

    func parentSetLevel(_ tier: Tier) {
        progress.ladder.parentSet(tier)
        try? store.save(progress)
    }

    func parentReset() {
        progress = .fresh
        try? store.save(progress)
    }

    func revealCustomWordsFile() {
        store.ensureCustomWordsFile()
        NSWorkspace.shared.activateFileViewerSelecting([store.customWordsURL])
    }
}
#endif
