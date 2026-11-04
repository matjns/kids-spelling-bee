#if os(macOS)
import SwiftUI
import SpellingBeeCore

struct RootView: View {
    @ObservedObject var model: BeeModel

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            switch model.screen {
            case .home:
                HomeView(model: model)
            case .playing:
                PlayView(model: model)
            case .beeOver:
                BeeOverView(model: model)
            }
            if model.showConfetti {
                ConfettiView().ignoresSafeArea()
            }
            if let tier = model.levelUp {
                LevelUpOverlay(
                    title: "You reached \(tier.title) words!",
                    message: "Your spelling is getting stronger. Here come trickier words.",
                    dismiss: { model.levelUp = nil }
                )
            }
        }
        .frame(minWidth: 900, minHeight: 680)
    }
}

struct HomeView: View {
    @ObservedObject var model: BeeModel

    var body: some View {
        VStack(spacing: 28) {
            Text("🐝 Spelling Bee")
                .font(.system(size: 60, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.ink)
            Text("Listen to the word, then type how it's spelled.")
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.75))
            LevelBadge(
                levelName: model.progress.ladder.tier.title,
                progress: model.progress.ladder.progressToNext,
                isTop: model.progress.ladder.tier.next == nil
            )
            .padding(20)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            HStack(spacing: 22) {
                BigButton(title: "Practice", subtitle: "No strikes. Learn at your pace.", fill: Palette.blue) {
                    model.start(.practice)
                }
                BigButton(title: "Bee Challenge", subtitle: "3 strikes. Words get harder!", fill: Palette.sun, ink: Palette.ink) {
                    model.start(.bee)
                }
            }
            .frame(maxWidth: 720)
            HStack(spacing: 30) {
                stat("⭐️", "\(model.progress.stars)", "stars")
                stat("🔥", "\(model.progress.bestStreak)", "best streak")
                stat("🏆", "\(model.progress.bestBeeScore)", "best bee")
                stat("🔁", "\(model.progress.review.count)", "to review")
            }
        }
        .padding(40)
    }

    private func stat(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(icon) \(value)").font(.system(size: 26, weight: .bold, design: .rounded))
            Text(label).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(Palette.ink.opacity(0.7))
        }
        .foregroundStyle(Palette.ink)
        .accessibilityElement(children: .combine)
    }
}

struct PlayView: View {
    @ObservedObject var model: BeeModel
    @FocusState private var typing: Bool

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                PillButton(title: "Home", systemImage: "house.fill") { model.goHome() }
                Spacer()
                if let session = model.session {
                    if session.mode == .bee {
                        Text("Round \(session.beeRound)  •  Score \(session.beeScore)  •  " + strikesText(session.strikes))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                    } else {
                        Text("Level: \(session.progress.ladder.tier.title)  •  Streak \(session.streak) 🔥")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                    }
                }
            }
            .foregroundStyle(Palette.ink)

            if let tier = model.steppedDown {
                StepDownBanner(levelName: tier.title)
            }

            Button(action: model.sayWord) {
                Label("Hear the word", systemImage: "speaker.wave.3.fill")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 22)
                    .background(Palette.blue, in: Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("r", modifiers: [.command])

            HStack(spacing: 14) {
                PillButton(title: "Repeat", systemImage: "arrow.counterclockwise", action: model.sayWord)
                PillButton(title: "Slower", systemImage: "tortoise.fill", action: model.saySlower)
                PillButton(title: "Sentence", systemImage: "text.quote", action: model.saySentence)
                PillButton(title: "Definition", systemImage: "book.fill", action: model.sayDefinition)
            }

            if let hint = model.hintShown {
                Text(hint)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 700)
            }

            if let result = model.result, let word = model.word {
                ResultView(result: result, word: word, typed: model.typed) {
                    model.continueAfterAnswer()
                }
            } else {
                TextField("Type the word here", text: $model.typed)
                    .textFieldStyle(.plain)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .autocorrectionDisabled(true)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: 620)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Palette.blue.opacity(0.4), lineWidth: 2))
                    .focused($typing)
                    .onSubmit { model.submit() }
                BigButton(title: "Check my spelling", fill: Palette.leaf) { model.submit() }
                    .frame(width: 360)
            }
            Spacer(minLength: 0)
        }
        .padding(36)
        .onAppear { typing = true }
        .onChange(of: model.result == nil) { _, isTyping in
            if isTyping { typing = true }
        }
    }

    private func strikesText(_ strikes: Int) -> String {
        let left = max(0, BeeSession.strikesAllowed - strikes)
        return String(repeating: "❤️", count: left) + String(repeating: "🤍", count: BeeSession.strikesAllowed - left)
    }
}

struct ResultView: View {
    var result: AnswerResult
    var word: WordEntry
    var typed: String
    var next: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            if result.correct {
                Text("🎉 Correct! 🎉")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.leaf)
                Text(word.word)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
            } else {
                Text(SpellingDiff.coaching(typed: typed, word: word.word))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                LetterDiffView(marks: result.marks)
                Text("The word is **\(word.word)**. It will come back later for another try.")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.75))
            }
            BigButton(title: "Next word", fill: Palette.blue, action: next)
                .frame(width: 300)
                .keyboardShortcut(.defaultAction)
        }
    }
}

/// Shows each letter of the right spelling. Green = right, orange = fix this one,
/// dashed = a letter that was left out. Extra letters are shown crossed out.
struct LetterDiffView: View {
    var marks: [LetterMark]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                tile(for: mark)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Letter by letter comparison")
    }

    @ViewBuilder
    private func tile(for mark: LetterMark) -> some View {
        switch mark {
        case .same(let c):
            letterBox(String(c), fill: Palette.leaf.opacity(0.18), ink: Palette.leaf, caption: " ")
        case .swapped(let expected, let typedLetter):
            letterBox(String(expected), fill: Palette.sun.opacity(0.35), ink: Palette.ink, caption: "not \(typedLetter)")
        case .missing(let c):
            letterBox(String(c), fill: Palette.sky, ink: Palette.blue, caption: "missed", dashed: true)
        case .extra(let c):
            letterBox(String(c), fill: Color.gray.opacity(0.12), ink: Color.gray, caption: "extra", strike: true)
        }
    }

    private func letterBox(_ letter: String, fill: Color, ink: Color, caption: String, dashed: Bool = false, strike: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(letter)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .strikethrough(strike)
                .foregroundStyle(ink)
                .frame(width: 50, height: 62)
                .background(fill, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(ink.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: dashed ? [5, 4] : []))
                )
            Text(caption)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.7))
        }
    }
}

struct BeeOverView: View {
    @ObservedObject var model: BeeModel

    var body: some View {
        VStack(spacing: 24) {
            Text("🐝 Bee complete!")
                .font(.system(size: 54, weight: .heavy, design: .rounded))
            Text("You spelled \(model.session?.beeScore ?? 0) words and reached round \(model.session?.beeRound ?? 1).")
                .font(.system(size: 24, weight: .medium, design: .rounded))
            if (model.session?.beeScore ?? 0) >= model.progress.bestBeeScore, (model.session?.beeScore ?? 0) > 0 {
                Text("🏆 That's your best bee yet!")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.leaf)
            }
            HStack(spacing: 20) {
                BigButton(title: "Try again", fill: Palette.sun, ink: Palette.ink) { model.start(.bee) }
                BigButton(title: "Home", fill: Palette.blue) { model.goHome() }
            }
            .frame(maxWidth: 560)
        }
        .foregroundStyle(Palette.ink)
        .padding(40)
    }
}

#endif
