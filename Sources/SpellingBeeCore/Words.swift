import Foundation

/// One word in the bee, with a short kid-friendly definition and sentence.
public struct WordEntry: Codable, Equatable, Hashable, Sendable {
    public var word: String
    public var definition: String
    public var sentence: String
    public var tier: Tier

    public init(word: String, definition: String, sentence: String, tier: Tier) {
        self.word = word
        self.definition = definition
        self.sentence = sentence
        self.tier = tier
    }

    enum CodingKeys: String, CodingKey { case word, definition, sentence, tier }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        word = try c.decode(String.self, forKey: .word).trimmingCharacters(in: .whitespacesAndNewlines)
        definition = try c.decodeIfPresent(String.self, forKey: .definition) ?? ""
        sentence = try c.decodeIfPresent(String.self, forKey: .sentence) ?? ""
        let tierName = (try c.decodeIfPresent(String.self, forKey: .tier) ?? "easy").lowercased()
        switch tierName {
        case "medium": tier = .medium
        case "advanced", "hard": tier = .advanced
        default: tier = .easy
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(word, forKey: .word)
        try c.encode(definition, forKey: .definition)
        try c.encode(sentence, forKey: .sentence)
        let name: String
        switch tier {
        case .easy: name = "easy"
        case .medium: name = "medium"
        case .advanced: name = "advanced"
        }
        try c.encode(name, forKey: .tier)
    }

    /// The sentence with the word hidden, for showing on screen.
    public var blankedSentence: String {
        var result = sentence
        let options: String.CompareOptions = [.caseInsensitive]
        while let range = result.range(of: word, options: options) {
            result.replaceSubrange(range, with: String(repeating: "_", count: 5))
        }
        return result
    }

    /// Key used for the review queue and stats.
    public var key: String { AnswerChecker.normalize(word) }
}

/// The editable custom word list file format.
public struct CustomWordFile: Codable, Equatable {
    public var howTo: String?
    public var words: [WordEntry]

    public init(howTo: String? = CustomWordFile.instructions, words: [WordEntry] = []) {
        self.howTo = howTo
        self.words = words
    }

    public static let instructions = "Add words to the list below, then quit and reopen Spelling Bee. Each word needs \"word\", and can have \"definition\", \"sentence\", and \"tier\" (easy, medium, or advanced)."
    public static let fileName = "custom-words.json"

    public static let example = CustomWordFile(words: [
        WordEntry(word: "spelling", definition: "Putting letters in the right order to make a word.", sentence: "Spelling gets easier with practice.", tier: .easy)
    ])
}

public enum WordBank {
    /// The built-in list (several hundred words).
    public static let builtIn: [WordEntry] = {
        guard let data = WordListData.json.data(using: .utf8),
              let words = try? JSONDecoder().decode([WordEntry].self, from: data) else {
            return []
        }
        return words
    }()

    public static func decodeCustom(_ data: Data) throws -> [WordEntry] {
        let file = try JSONDecoder().decode(CustomWordFile.self, from: data)
        return file.words.filter { !AnswerChecker.normalize($0.word).isEmpty }
    }

    /// Built-in words plus custom ones. A custom word replaces a built-in word with the same spelling.
    public static func merged(builtIn: [WordEntry] = builtIn, custom: [WordEntry]) -> [WordEntry] {
        var seen = Set<String>()
        var result: [WordEntry] = []
        for entry in custom + builtIn where !seen.contains(entry.key) {
            seen.insert(entry.key)
            result.append(entry)
        }
        return result
    }

    public static func words(in tier: Tier, from list: [WordEntry]) -> [WordEntry] {
        list.filter { $0.tier == tier }
    }
}
