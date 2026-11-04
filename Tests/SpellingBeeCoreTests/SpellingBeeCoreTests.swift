import XCTest
@testable import SpellingBeeCore

final class AnswerCheckerTests: XCTestCase {
    func testCaseAndSpacesDoNotMatter() {
        XCTAssertTrue(AnswerChecker.isCorrect(typed: "  Because ", word: "because"))
        XCTAssertTrue(AnswerChecker.isCorrect(typed: "WEDNESDAY", word: "Wednesday"))
        XCTAssertTrue(AnswerChecker.isCorrect(typed: "nobody\u{2019}s", word: "nobody's"))
    }

    func testWrongAndEmptyAreWrong() {
        XCTAssertFalse(AnswerChecker.isCorrect(typed: "becuase", word: "because"))
        XCTAssertFalse(AnswerChecker.isCorrect(typed: "", word: "because"))
        XCTAssertFalse(AnswerChecker.isCorrect(typed: "becaus", word: "because"))
    }
}

final class SpellingDiffTests: XCTestCase {
    func testPerfectMatchIsAllSame() {
        let marks = SpellingDiff.compare(typed: "friend", word: "friend")
        XCTAssertEqual(marks.count, 6)
        XCTAssertTrue(marks.allSatisfy { $0.isSame })
    }

    func testMissingLetter() {
        let marks = SpellingDiff.compare(typed: "frend", word: "friend")
        XCTAssertEqual(marks.filter { !$0.isSame }, [.missing("i")])
        XCTAssertEqual(SpellingDiff.mistakes(typed: "frend", word: "friend"), 1)
    }

    func testExtraLetter() {
        let marks = SpellingDiff.compare(typed: "untill", word: "until")
        XCTAssertEqual(marks.filter { !$0.isSame }, [.extra("l")])
    }

    func testSwappedLetter() {
        let marks = SpellingDiff.compare(typed: "desart", word: "desert")
        XCTAssertEqual(marks, [.same("d"), .same("e"), .same("s"), .swapped(expected: "e", typed: "a"), .same("r"), .same("t")])
    }

    func testEmptyTypedIsAllMissing() {
        let marks = SpellingDiff.compare(typed: "", word: "cat")
        XCTAssertEqual(marks, [.missing("c"), .missing("a"), .missing("t")])
    }

    func testCoachingIsKind() {
        XCTAssertTrue(SpellingDiff.coaching(typed: "frend", word: "friend").contains("one letter"))
    }
}

final class ReviewQueueTests: XCTestCase {
    func testMissedWordComesBackAfterGap() {
        var q = ReviewQueue()
        q.advance()
        q.missed("because")
        XCTAssertNil(q.due())
        for _ in 0..<ReviewQueue.gaps[0] { q.advance() }
        XCTAssertEqual(q.due(), "because")
    }

    func testCorrectReviewsWaitLongerThenGraduate() {
        var q = ReviewQueue()
        q.missed("ocean")
        for box in 1..<ReviewQueue.gaps.count {
            q.correct("ocean")
            XCTAssertEqual(q.items.first?.box, box)
            XCTAssertEqual(q.items.first?.dueTurn, q.turn + ReviewQueue.gaps[box])
        }
        q.correct("ocean")
        XCTAssertEqual(q.count, 0)
    }

    func testMissAgainResetsBox() {
        var q = ReviewQueue()
        q.missed("ocean")
        q.correct("ocean")
        q.missed("ocean")
        XCTAssertEqual(q.count, 1)
        XCTAssertEqual(q.items.first?.box, 0)
    }

    func testCodableRoundTrip() throws {
        var q = ReviewQueue()
        q.missed("a"); q.advance(); q.missed("b")
        let data = try JSONEncoder().encode(q)
        XCTAssertEqual(try JSONDecoder().decode(ReviewQueue.self, from: data), q)
    }
}

final class LevelLadderTests: XCTestCase {
    func testStartsEasyAndLevelsUpOnMastery() {
        var ladder = LevelLadder()
        XCTAssertEqual(ladder.tier, .easy)
        var change: LevelChange?
        for i in 0..<10 { change = ladder.record(correct: i != 3 && i != 6) }
        XCTAssertEqual(change, .levelUp(.medium))
        XCTAssertEqual(ladder.tier, .medium)
        XCTAssertTrue(ladder.recent.isEmpty)
    }

    func testNoLevelUpBeforeTenAnswers() {
        var ladder = LevelLadder()
        for _ in 0..<9 { XCTAssertNil(ladder.record(correct: true)) }
        XCTAssertEqual(ladder.record(correct: true), .levelUp(.medium))
    }

    func testStepsDownOnlyWhenStrugglingALot() {
        var ladder = LevelLadder(tier: .medium)
        // Half right is not struggling enough to step down.
        for i in 0..<20 { XCTAssertNil(ladder.record(correct: i % 2 == 0)) }
        var change: LevelChange?
        for _ in 0..<10 { change = ladder.record(correct: false) ?? change }
        XCTAssertEqual(change, .stepDown(.easy))
        XCTAssertEqual(ladder.best, .medium)
    }

    func testEasyNeverStepsDownAndAdvancedTops() {
        var ladder = LevelLadder()
        for _ in 0..<30 { XCTAssertNil(ladder.record(correct: false)) }
        ladder.setTierForTesting(.advanced)
        for _ in 0..<30 { XCTAssertNil(ladder.record(correct: true)) }
        XCTAssertEqual(ladder.tier, .advanced)
        XCTAssertEqual(ladder.progressToNext, 1)
    }
}

final class WordBankTests: XCTestCase {
    func testBuiltInListIsBigAndClean() {
        let words = WordBank.builtIn
        XCTAssertGreaterThanOrEqual(words.count, 400)
        for tier in Tier.allCases {
            XCTAssertGreaterThanOrEqual(WordBank.words(in: tier, from: words).count, 100, "\(tier)")
        }
        XCTAssertEqual(Set(words.map { $0.key }).count, words.count, "duplicate words")
        for w in words {
            XCTAssertFalse(w.definition.isEmpty, w.word)
            XCTAssertFalse(w.sentence.isEmpty, w.word)
            XCTAssertFalse(w.blankedSentence.lowercased().contains(w.word.lowercased()), w.word)
        }
    }

    func testCustomListDecodesAndOverrides() throws {
        let json = """
        {"howTo": "x", "words": [
          {"word": "because", "definition": "Custom.", "sentence": "Because I said so.", "tier": "advanced"},
          {"word": "zigzag"},
          {"word": "   "}
        ]}
        """
        let custom = try WordBank.decodeCustom(Data(json.utf8))
        XCTAssertEqual(custom.count, 2)
        XCTAssertEqual(custom[1].tier, .easy)
        let merged = WordBank.merged(custom: custom)
        XCTAssertEqual(merged.filter { $0.key == "because" }.count, 1)
        XCTAssertEqual(merged.first { $0.key == "because" }?.tier, .advanced)
    }

    func testStoreRoundTripAndCustomFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ProgressStore(directory: dir)
        XCTAssertEqual(store.load(), .fresh)
        var p = BeeProgress()
        p.stars = 7
        try store.save(p)
        XCTAssertEqual(store.load().stars, 7)
        store.ensureCustomWordsFile()
        let loaded = store.loadCustomWords()
        XCTAssertNil(loaded.problem)
        XCTAssertEqual(loaded.words.count, 1)
        try Data("{oops".utf8).write(to: store.customWordsURL)
        XCTAssertNotNil(store.loadCustomWords().problem)
    }
}

final class SessionTests: XCTestCase {
    func testMissedWordIsRequeuedLater() {
        var s = BeeSession(mode: .practice, progress: .fresh, words: WordBank.builtIn, seed: 42)
        let first = s.nextWord()!
        let result = s.submit("zzz")!
        XCTAssertFalse(result.correct)
        XCTAssertTrue(s.progress.review.contains(first.key))
        var sawAgain = false
        for _ in 0..<6 {
            let w = s.nextWord()!
            if w.key == first.key { sawAgain = true; break }
            _ = s.submit(w.word)
        }
        XCTAssertTrue(sawAgain)
    }

    func testPracticeStartsEasyAndLevelsUp() {
        var s = BeeSession(mode: .practice, progress: .fresh, words: WordBank.builtIn, seed: 7)
        XCTAssertEqual(s.nextWord()?.tier, .easy)
        var sawLevelUp = false
        for _ in 0..<10 {
            if s.current == nil { _ = s.nextWord() }
            if s.submit(s.current!.word)?.levelChange == .levelUp(.medium) { sawLevelUp = true }
        }
        XCTAssertTrue(sawLevelUp)
        XCTAssertEqual(s.nextWord()?.tier, .medium)
    }

    func testBeeEndsAfterThreeStrikes() {
        var s = BeeSession(mode: .bee, progress: .fresh, words: WordBank.builtIn, seed: 1)
        for i in 0..<3 {
            XCTAssertNotNil(s.nextWord())
            let r = s.submit("qqqq")!
            XCTAssertEqual(r.beeOver, i == 2)
        }
        XCTAssertNil(s.nextWord())
    }

    func testBeeRoundsGetHarder() {
        var s = BeeSession(mode: .bee, progress: .fresh, words: WordBank.builtIn, seed: 3)
        XCTAssertEqual(s.activeTier, .easy)
        for _ in 0..<(BeeSession.wordsPerBeeRound * 2) {
            let w = s.nextWord()!
            _ = s.submit(w.word)
        }
        XCTAssertEqual(s.beeRound, 3)
        XCTAssertGreaterThan(s.activeTier, .easy)
    }
}
