import Foundation

public enum PlayMode: String, Codable, Sendable {
    /// Endless practice, no strikes.
    case practice
    /// Three strikes and the bee is over. Rounds get harder.
    case bee
}

/// Everything saved between launches.
public struct BeeProgress: Codable, Equatable, Sendable {
    public var ladder = LevelLadder()
    public var review = ReviewQueue()
    public var wordsSpelled = 0
    public var wordsTried = 0
    public var stars = 0
    public var bestBeeScore = 0
    public var bestStreak = 0
    public var mastered: [String] = []

    public init() {}

    public static let fresh = BeeProgress()
}

public struct AnswerResult: Equatable, Sendable {
    public var correct: Bool
    public var marks: [LetterMark]
    public var levelChange: LevelChange?
    public var beeOver: Bool
}

/// The rules of one play session. No UI here, so it is tested on Linux.
public struct BeeSession {
    public static let wordsPerBeeRound = 5
    public static let strikesAllowed = 3

    public let mode: PlayMode
    public private(set) var progress: BeeProgress
    public private(set) var current: WordEntry?
    public private(set) var strikes = 0
    public private(set) var beeScore = 0
    public private(set) var streak = 0
    public private(set) var beeRound = 1
    public private(set) var recentKeys: [String] = []

    private let words: [WordEntry]
    private var rng: SplitMix64

    public init(mode: PlayMode, progress: BeeProgress, words: [WordEntry], seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        self.mode = mode
        self.progress = progress
        self.words = words
        self.rng = SplitMix64(seed: seed)
    }

    public var isOver: Bool { mode == .bee && strikes >= Self.strikesAllowed }

    /// The tier words are drawn from right now. In a bee, every two rounds reach one tier higher.
    public var activeTier: Tier {
        var tier = progress.ladder.tier
        if mode == .bee {
            var steps = (beeRound - 1) / 2
            while steps > 0, let next = tier.next { tier = next; steps -= 1 }
        }
        return tier
    }

    public mutating func nextWord() -> WordEntry? {
        guard !isOver else { return nil }
        progress.review.advance()
        let byKey = Dictionary(words.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        var pick: WordEntry?
        if let dueKey = progress.review.due(), let entry = byKey[dueKey], !recentKeys.suffix(1).contains(dueKey) {
            pick = entry
        }
        if pick == nil {
            var pool = WordBank.words(in: activeTier, from: words)
            if pool.isEmpty { pool = words }
            let fresh = pool.filter { !recentKeys.contains($0.key) && !progress.mastered.contains($0.key) }
            let unseenRecent = pool.filter { !recentKeys.contains($0.key) }
            let source = !fresh.isEmpty ? fresh : (!unseenRecent.isEmpty ? unseenRecent : pool)
            if !source.isEmpty { pick = rng.pick(source) }
        }
        current = pick
        if let key = pick?.key {
            recentKeys.append(key)
            if recentKeys.count > 30 { recentKeys.removeFirst() }
        }
        return pick
    }

    public mutating func submit(_ typed: String) -> AnswerResult? {
        guard let word = current else { return nil }
        let correct = AnswerChecker.isCorrect(typed: typed, word: word.word)
        let marks = SpellingDiff.compare(typed: typed, word: word.word)
        progress.wordsTried += 1
        if correct {
            progress.wordsSpelled += 1
            streak += 1
            progress.bestStreak = max(progress.bestStreak, streak)
            progress.stars += 1
            if progress.review.contains(word.key) {
                progress.review.correct(word.key)
            } else if !progress.mastered.contains(word.key) {
                progress.mastered.append(word.key)
            }
            if mode == .bee {
                beeScore += 1
                if beeScore % Self.wordsPerBeeRound == 0 { beeRound += 1 }
                progress.bestBeeScore = max(progress.bestBeeScore, beeScore)
            }
        } else {
            streak = 0
            progress.review.missed(word.key)
            progress.mastered.removeAll { $0 == word.key }
            if mode == .bee { strikes += 1 }
        }
        let change = progress.ladder.record(correct: correct)
        current = nil
        return AnswerResult(correct: correct, marks: marks, levelChange: change, beeOver: isOver)
    }
}
