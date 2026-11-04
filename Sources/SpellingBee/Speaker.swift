#if os(macOS)
import AVFoundation
import Foundation

/// Says words with the Mac's built-in, offline voices.
@MainActor
final class Speaker {
    private let synthesizer = AVSpeechSynthesizer()
    private let voice: AVSpeechSynthesisVoice?

    /// A bit slower than normal talking, so every sound is clear.
    static let normalRate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.85
    static let slowRate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.6

    init() {
        voice = Speaker.bestVoice()
    }

    /// Prefer a premium or enhanced US English voice if one is installed, then any US English voice.
    static func bestVoice() -> AVSpeechSynthesisVoice? {
        let us = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }
        if let premium = us.first(where: { $0.quality == .premium }) { return premium }
        if let enhanced = us.first(where: { $0.quality == .enhanced }) { return enhanced }
        let clear = ["Samantha", "Allison", "Ava", "Susan", "Tom", "Alex"]
        for name in clear {
            if let match = us.first(where: { $0.name.hasPrefix(name) }) { return match }
        }
        return us.first ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    var voiceName: String { voice?.name ?? "System voice" }

    func say(_ text: String, slow: Bool = false) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = slow ? Speaker.slowRate : Speaker.normalRate
        utterance.preUtteranceDelay = 0.1
        synthesizer.speak(utterance)
    }

    /// Spells a word out loud, letter by letter.
    func spell(_ word: String) {
        let letters = word.map { $0 == " " ? "space" : String($0).uppercased() }
        say(letters.joined(separator: ", "), slow: true)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
#endif
