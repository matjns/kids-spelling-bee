# Spelling Bee

Spelling Bee is a small Mac app for kids about 8 to 13. The Mac says a word out loud, and you type how it's spelled.

- **Hear the word** says it again any time. **Slower**, **Sentence**, and **Definition** help, just like asking the judge at a real bee.
- A right answer gets a cheer and confetti.
- A miss shows a gentle letter-by-letter view: green letters were right, orange ones need fixing, dashed boxes are letters that were left out, and crossed-out ones were extra. The Mac then spells the word out loud.
- Missed words come back a few words later, then again after a longer wait, until they stick (spaced repetition).

## Modes

- **Practice**: no strikes, as long as you like.
- **Bee Challenge**: three strikes and the bee is over. Every two rounds of five words, the words get harder.

## Levels go up on their own

There is no level picker. Everyone starts on **Easy** (about ages 8 and 9). Get 8 of your last 10 words right and you level up to **Medium**, then **Advanced** (about ages 11 to 13), with a big "Level up!" moment. If someone misses almost every word for a while (2 or fewer right out of 10), the app gently steps back one level. The level is remembered between launches.

## Words

The app comes with 413 words: 141 Easy, 138 Medium, 134 Advanced. Each has a short kid-friendly definition and a sentence. The lists are in `Data/*.txt`, one word per line as `word|definition|sentence`. After editing them, run `python3 Data/generate.py` to rebuild `Sources/SpellingBeeCore/WordListData.swift`.

### Your own word list

You can add words, for example this week's school spelling list. This is file-only: there is no settings screen in the app. The first launch writes an example file named `custom-words.json`:

`~/Library/Containers/com.kidscomputer.spellingbee/Data/Library/Application Support/SpellingBee/custom-words.json`

Each entry needs `"word"`, and can have `"definition"`, `"sentence"`, and `"tier"` (`easy`, `medium`, or `advanced`; easy if left out):

```json
{
  "words": [
    { "word": "necessary", "definition": "Needed.", "sentence": "Water is necessary for life.", "tier": "medium" }
  ]
}
```

Save the file, then quit and reopen Spelling Bee to load the new words. A custom word replaces a built-in word with the same spelling.


## The voice

The app uses the Mac's built-in speech, which works offline. It picks the best installed US English voice (Premium, then Enhanced, then a standard voice such as Samantha) and talks a little slower than normal. For a clearer voice, download an Enhanced or Premium US English voice in System Settings > Accessibility > Spoken Content > System Voice > Manage Voices.

## Download and install

Not released yet. When a release exists it will be on https://github.com/matjns/kids-spelling-bee/releases as `SpellingBee-mac-universal.zip`. It runs on Apple silicon and Intel, and needs macOS 14 or later. It is not signed with an Apple Developer ID, so macOS warns the first time you open it. The steps are in `README-mac.txt`.

Put `Spelling Bee.app` in `/Applications`.

## Kids Computer

The Kids Computer launcher (https://github.com/matjns/kids-computer) can open it with the bundle id `com.kidscomputer.spellingbee`. Command-Q quits, and closing the window quits too, so the launcher comes back.

## Privacy

No network, no accounts, no ads, no links out. Progress (`progress.json`) and the custom word list stay in the app's Application Support folder on this Mac.

## Build it yourself

You need a Mac with macOS 14 or later and Xcode 15 or later.

```bash
./build.sh test
./build.sh
```

`./build.sh test` runs the word, spelling-check, and level tests (also on Linux, anywhere Swift is installed). `./build.sh` writes `build/Spelling Bee.app` and `dist/SpellingBee-mac-universal.zip`.

The words, answer checking, letter comparison, review queue, and levels live in `SpellingBeeCore`. The window and the voice are the `SpellingBee` target.

What is left before an App Store submission is in `docs/APP_STORE.md`.

## License

MIT. See `LICENSE`.
