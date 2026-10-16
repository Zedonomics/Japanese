# Curriculum and refresh procedure

The app bundles 311 stable learning items: 46 basic kana, 25 voiced kana, and
33 contracted combinations per script; small-tsu exercises for both scripts;
a katakana long-vowel exercise; and 100 kanji. The 208 non-contextual kana
items gate kanji access. The three contextual items do not gate access.

`assets/curriculum/items.json` is a versioned object with an `items` array.
Identifiers derive from script and Unicode glyphs, so dictionary refreshes
do not invalidate saved progress. Kanji `frequencyRank` is the actual
KANJIDIC2 newspaper-frequency rank. It must never be inferred from a manually
typed list or replaced with a beginner-school ordering.

Kana teaching order is vowels and basic rows, voiced rows, then contracted
sounds. Romaji aliases cover standard alternate spellings. Reverse prompts
distinguish お/を, じ/ぢ, and ず/づ by their row or grammatical role. The app
preserves the small/large character distinction. Small っ/ッ is taught with
きって/カップ, and ー with コーヒー, rather than claiming standalone sounds.
Their reading exercises require the full example's romaji; production
exercises require only the symbol identified by the cue.

Each kanji teaches one chosen reading in one clearly labeled example. The
answer is the hiragana reading of the highlighted kanji alone, excluding
okurigana and other kanji. For example, 長 in 長い requires なが; 長い as a
whole is ながい. Reading mastery does not imply that all readings of that
kanji have been learned. Context examples avoid changes such as 学 = がっ
in 学校: the starter example 学生 consistently teaches がく instead.

`kanji_seeds.psv` contains the reviewed selection of readings, condensed
meanings, and examples. `dictionary_evidence.json` records a matching JMdict
entry ID for every example. `sources.json` records source dates, SHA-256
hashes, and the pinned KanjiVG commit. All required glyphs have an original
KanjiVG SVG named by five-digit hexadecimal code point, for example
`assets/strokes/03042.svg`. Multi-character combinations display constituent
diagrams separately. Stroke numbers guide order; recognition grades identity,
not stroke order or calligraphy.

## Refresh

Run from the repository root on Windows with PowerShell and `curl.exe`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/refresh_curriculum.ps1
```

Downloads go to the operating system's temporary directory by default. Use
`-SourceDirectory C:\path\to\cache -SkipDownload` to rebuild and validate
from previously downloaded `kanjidic2.xml.gz`, `JMdict_e.gz`, and
`kanjivg.zip`. `-SkipStrokes` reuses existing SVG files and still verifies
coverage. The script works with Windows PowerShell 5.1 and PowerShell 7.

The script fetches the current dictionaries, verifies ranks 1-100 are unique
and complete, verifies each taught reading against KANJIDIC2, verifies each
example word/reading against JMdict (including reading restrictions), checks
all kana counts and stable IDs, and confirms every required SVG exists. It
writes the bundled curriculum only after validation passes. The KanjiVG
source is pinned in the script; update that commit deliberately after
reviewing upstream changes. Refresh the EDRDG and Creative Commons license
copies if their published statements change.

Before distributing an updated app, run the refresh, review the generated
diff, and run the app's tests and build. Check for dictionary updates at
least monthly during active development and before each release. If a new
top-100 character replaces an old one, the script stops until its reviewed
seed is added and the removed seed is retired. Update `reviewedOn` in the
script after editorial review; a successful download alone is not review.
Never silently replace a taught reading under an existing item ID: introduce
a content migration if a reading correction changes the grading contract.

## Current validation

The initial dictionary snapshots are dated 2026-10-16. All 100 example
word/reading pairs exist in JMdict, and all 100 taught character readings
exist in KANJIDIC2. This verifies dictionary agreement; it is not a claim of
an independent native-speaker curriculum review.
