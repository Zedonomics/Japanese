# Sources and privacy

The app's Sources screen should show `assets/licenses/NOTICE.txt`, including
the local full license and documentation copies. The following files are
shipped with the app:

- Dictionary-derived curriculum and provenance: `assets/curriculum/`.
- KANJIDIC2 documentation and EDRDG license statement:
  `assets/licenses/KANJIDIC2-documentation.html` and `EDRDG-licence.html`.
- Creative Commons Attribution-ShareAlike 4.0 legal code:
  `assets/licenses/CC-BY-SA-4.0.txt`.
- KanjiVG stroke diagrams: `assets/strokes/`, unchanged from pinned commit
  `70a0b7ae0c18ceb5cb358274b029cce0234a43bc`.
- KanjiVG's Creative Commons Attribution-ShareAlike 3.0 license:
  `assets/licenses/KanjiVG-COPYING.txt`.

KANJIDIC2 and JMdict are copyright James William Breen and EDRDG. Dictionary
selection, condensed definitions, explanations, and curriculum arrangement
are distributed as an adaptation under CC BY-SA 4.0. KanjiVG is copyright
2009-2026 Ulrich Apel and contributors, under CC BY-SA 3.0. The licenses for
these data assets do not automatically relicense the independent application
software. Preserve attribution and applicable share-alike terms when
redistributing or editing the assets.

Primary references:

- [EDRDG dictionary license](https://www.edrdg.org/edrdg/licence.html)
- [KANJIDIC2 field and frequency documentation](https://www.edrdg.org/kanjidic/kanjidic2_dtdh.html)
- [JMdict project](https://www.edrdg.org/jmdict/j_jmdict.html)
- [KanjiVG project and licensing](https://kanjivg.tagaini.net/)
- [KanjiVG source](https://github.com/KanjiVG/kanjivg)
- [ML Kit digital ink documentation](https://developers.google.com/ml-kit/vision/digital-ink-recognition)
- [ML Kit terms and privacy](https://developers.google.com/ml-kit/terms)

Progress, review attempts, settings, and unfinished lessons stay in the app's
local database. A backup contains learning progress and settings; users
choose where to save or share it. The app has no account or synchronization
service.

Digital ink recognition runs on the device after the Japanese model is
downloaded. The initial download and retries require network access. The
Google ML Kit SDK has its own diagnostics and usage-data behavior described
in Google's terms; the app should link that information instead of claiming
that the SDK makes no network requests. Lessons and handwriting recognition
can run offline once the model is present. The curriculum's provenance files
contain no user data.
