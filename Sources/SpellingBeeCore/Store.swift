import Foundation

public enum SpellingBeeRelease {
    public static let appName = "Spelling Bee"
    public static let bundleID = "com.kidscomputer.spellingbee"
    public static let supportFolder = "SpellingBee"
    public static let progressFileName = "progress.json"
}

private struct ProgressEnvelope: Codable {
    var version: Int
    var progress: BeeProgress
}

/// Saves progress and the custom word list in Application Support.
public struct ProgressStore {
    public var directory: URL
    public var fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    public var fileURL: URL { directory.appendingPathComponent(SpellingBeeRelease.progressFileName) }
    public var customWordsURL: URL { directory.appendingPathComponent(CustomWordFile.fileName) }

    public func load() -> BeeProgress {
        guard let data = try? Data(contentsOf: fileURL),
              let envelope = try? JSONDecoder().decode(ProgressEnvelope.self, from: data) else {
            return .fresh
        }
        return envelope.progress
    }

    public func save(_ progress: BeeProgress) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(ProgressEnvelope(version: 1, progress: progress))
        try data.write(to: fileURL, options: .atomic)
    }

    /// Writes an example custom list the first time, so there is something to edit.
    public func ensureCustomWordsFile() {
        guard !fileManager.fileExists(atPath: customWordsURL.path) else { return }
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(CustomWordFile.example) {
            try? data.write(to: customWordsURL, options: .atomic)
        }
    }

    /// Custom words, or an empty list plus a message if the file can't be read.
    public func loadCustomWords() -> (words: [WordEntry], problem: String?) {
        guard let data = try? Data(contentsOf: customWordsURL) else { return ([], nil) }
        do {
            return (try WordBank.decodeCustom(data), nil)
        } catch {
            return ([], "The custom word list has a typo, so only the built-in words are in use.")
        }
    }
}
