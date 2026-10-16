# Device verification checklist

**Status: Android release installation and native startup checked on a Pixel 9 Pro; lesson and input checks remain pending.** The iPhone, iOS simulator smoke test, and remote CI workflow are also pending until a run is recorded. Automated tests with a fake recognizer verify application behavior; they do not measure native recognition accuracy or keyboard conversion behavior.

Record the date, commit, phone/simulator model, OS version, app build, Japanese keyboard, and model-download status for each run. Check a box only after observing the result, and attach failure details when a check fails.

## Installation and startup

- [x] Pixel 9 Pro, Android 17 (API 37), version 1.0.1: install the APK, launch, and reach Learn. Native startup passed; user confirmed the Learn screen appears. Other Android versions remain untested.
- [ ] iOS simulator: complete the unsigned build and native smoke test; verify SQLite startup.
- [ ] iPhone iOS 15.5 or newer: configure personal signing on a Mac, install, and reach Learn. Signing is not configured in the repository.
- [ ] Open Library and inspect kana, combinations, symbol mini-lessons, and the ranked kanji list; verify Japanese text and stroke guides render.
- [ ] Check a small phone, system large text, light/dark appearance, keyboard visible, and rotation for clipped controls or overflow.

## Japanese keyboard and lesson flow

- [ ] Complete a kana reading lesson using romaji, including uppercase/whitespace and the accepted `shi`/`si` alternatives.
- [ ] In typing practice, switch to the real Japanese phone keyboard, enter kana, and submit committed text.
- [ ] While an IME candidate/composing region remains active, **Check answer** stays disabled and the keyboard's Done action does not grade it.
- [ ] Commit the IME conversion and verify the answer can then be checked. Test both kana entry and kanji conversion.
- [ ] Required script is enforced for typed answers: hiragana/katakana lookalikes and romaji in kanji lessons do not pass.
- [ ] Kana reverse prompts distinguish `o`/`wo`, `ji`/voiced `chi`, and `zu`/voiced `tsu` without displaying the expected answer.
- [ ] Each lesson has ten questions and at most three introduced items. Focused reading, typing, drawing, and mixed practice select the intended questions.
- [ ] Use a controlled test backup to reach the kana reading/typing milestone; verify kanji unlocks and remains available after a later kana mistake. Confirm drawing does not gate kanji.
- [ ] Kanji reading expects the taught hiragana reading. Production expects the highlighted kanji, using meaning/example context to avoid homophone ambiguity.

## Model download and real handwriting

- [ ] Before downloading a model, drawing shows its setup state and keyboard lessons work.
- [ ] Start the Japanese model download online; verify ready state. Test a failed/interrupted download and a successful retry.
- [ ] Draw with a finger and, if available, a stylus. Confirm Undo, Clear, single dots, pen lifts, and strokes near cell boundaries behave naturally.
- [ ] Readable handwritten kana and kanji produce useful native candidates. Stroke order is not a required grading criterion.
- [ ] Target at the native top candidate passes; a match only at rank two or three asks for a redraw without a progress penalty. A different recognized answer is incorrect.
- [ ] Test confusable pairs: し/つ, シ/ツ, ソ/ン, さ/き, あ/お, ぬ/め, and る/ろ.
- [ ] Test genuine shared shapes: カ/力, ニ/二, ハ/八, ー/一, ヘ/へ, ロ/口, エ/工, and タ/夕. Drawing accepts curated shape equivalents; typing remains exact.
- [ ] Test small versus full-sized ゃ/や, っ/つ and ャ/ヤ, ッ/ツ within fixed writing cells, plus two-character contracted sounds. The app must preserve relative character size.
- [ ] Try empty or unrecognized ink and a recognition interruption. Confirm no accidental success, no crash, and no progress penalty for an unavailable/error result.
- [ ] Record any consistent false rejection/acceptance with target, drawn strokes, native candidates, device, and OS. Do not treat simulator or unit-test success as handwriting-accuracy evidence.

## Persistence, offline use, and update

- [ ] With the model downloaded, turn on airplane mode. Start lessons, type answers, draw, view guides, and reopen the app successfully.
- [ ] Close/force-stop during an introduction, before an answer, and on graded feedback; relaunch and resume the exact saved point without counting an answer twice.
- [ ] Practice the same target repeatedly on one date; confirm it cannot gain a second scheduled mastery step. Mistakes and reveals reset that skill and schedule a retry in ten minutes.
- [ ] Export JSON to an external file. Restore it and verify progress, permanent unlock, and current lesson feedback/cursor.
- [ ] Try malformed and unrelated JSON; confirm existing progress remains unchanged.
- [ ] Install an update signed with the same development key and application ID; verify the database remains. Export first, then separately test restoration after a clean test install.
- [ ] Confirm no account/login or progress synchronization is required. Review the in-app source/license notices and model diagnostics disclosure.

## Run record

| Date / commit | Target / OS / keyboard | Checks performed | Result / remaining issues |
| --- | --- | --- | --- |
| 2026-10-16 / 1.0.0 build 1 | Pixel 9 Pro / Android 17 (API 37) | Reproduce immediate startup failure | Failed: WorkManager Room constructor removed by release optimization |
| 2026-10-16 / 1.0.1 build 2 | Pixel 9 Pro / Android 17 (API 37) | Same-signature update; non-debuggable cold start, 15 seconds, scoped logs; user opened app | Passed native startup; no fatal errors; user confirmed Learn appears. Lesson/input testing pending |
| 2026-10-16 / 1.0.1 build 2 | Pixel 9 Pro / Android 17 (API 37) | User completed lesson input/feedback/advance and downloaded handwriting model | Lesson and native model/recognition work. Failed canvas gesture: vertical-first strokes scroll the lesson; horizontal-first strokes can draw |
| Pending | iOS simulator / CI | Not run | Pending |
| Pending | Physical iPhone | Not run | Signing and verification deferred |
