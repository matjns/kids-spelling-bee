import Foundation

public enum AnswerChecker {
    /// Lowercased, trimmed, single spaces, straight apostrophes.
    public static func normalize(_ text: String) -> String {
        let replaced = text
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .lowercased()
        let parts = replaced.split(whereSeparator: { $0.isWhitespace })
        return parts.joined(separator: " ")
    }

    /// Capital letters and extra spaces do not count against the speller.
    public static func isCorrect(typed: String, word: String) -> Bool {
        let t = normalize(typed)
        return !t.isEmpty && t == normalize(word)
    }
}

/// One step of the letter-by-letter comparison.
public enum LetterMark: Equatable, Sendable {
    /// The letter was right.
    case same(Character)
    /// The speller typed `typed` where `expected` belongs.
    case swapped(expected: Character, typed: Character)
    /// The speller left out this letter.
    case missing(Character)
    /// The speller typed a letter that does not belong.
    case extra(Character)

    public var isSame: Bool {
        if case .same = self { return true }
        return false
    }
}

public enum SpellingDiff {
    /// A gentle letter-by-letter comparison (edit-distance alignment), in word order.
    public static func compare(typed: String, word: String) -> [LetterMark] {
        let a = Array(AnswerChecker.normalize(word))
        let b = Array(AnswerChecker.normalize(typed))
        let n = a.count, m = b.count
        var d = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { d[i][0] = i }
        for j in 0...m { d[0][j] = j }
        if n > 0 && m > 0 {
            for i in 1...n {
                for j in 1...m {
                    let cost = a[i - 1] == b[j - 1] ? 0 : 1
                    d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
                }
            }
        }
        var marks: [LetterMark] = []
        var i = n, j = m
        while i > 0 || j > 0 {
            if i > 0, j > 0, a[i - 1] == b[j - 1], d[i][j] == d[i - 1][j - 1] {
                marks.append(.same(a[i - 1])); i -= 1; j -= 1
            } else if i > 0, j > 0, d[i][j] == d[i - 1][j - 1] + 1 {
                marks.append(.swapped(expected: a[i - 1], typed: b[j - 1])); i -= 1; j -= 1
            } else if i > 0, d[i][j] == d[i - 1][j] + 1 {
                marks.append(.missing(a[i - 1])); i -= 1
            } else {
                marks.append(.extra(b[j - 1])); j -= 1
            }
        }
        return marks.reversed()
    }

    /// How many letters need fixing.
    public static func mistakes(typed: String, word: String) -> Int {
        compare(typed: typed, word: word).filter { !$0.isSame }.count
    }

    /// A short, kind sentence about the miss.
    public static func coaching(typed: String, word: String) -> String {
        let marks = compare(typed: typed, word: word)
        let wrong = marks.filter { !$0.isSame }.count
        if AnswerChecker.normalize(typed).isEmpty {
            return "Here's how it's spelled. You'll see it again soon."
        }
        if wrong == 1 { return "So close! Just one letter to fix." }
        if wrong == 2 { return "Nearly there. Two letters to fix." }
        return "Good try! Look at the letters, and you'll get another go later."
    }
}
