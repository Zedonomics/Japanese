[CmdletBinding()]
param(
    [string]$SourceDirectory = (Join-Path ([IO.Path]::GetTempPath()) 'kana-path-curriculum'),
    [switch]$SkipDownload,
    [switch]$SkipStrokes
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
$curriculumDirectory = Join-Path $repositoryRoot 'assets/curriculum'
$strokeDirectory = Join-Path $repositoryRoot 'assets/strokes'
$licenseDirectory = Join-Path $repositoryRoot 'assets/licenses'
$utf8 = [Text.UTF8Encoding]::new($false)
New-Item -ItemType Directory -Force $SourceDirectory, $curriculumDirectory, $strokeDirectory, $licenseDirectory | Out-Null

function Get-Source([string]$Url, [string]$Name) {
    $target = Join-Path $SourceDirectory $Name
    if (-not $SkipDownload) {
        & curl.exe --silent --show-error --location --fail --max-time 180 $Url --output $target
        if ($LASTEXITCODE -ne 0) { throw "Download failed: $Url" }
    }
    if (-not (Test-Path -LiteralPath $target)) { throw "Missing source: $target" }
    return $target
}

function Read-Gzip([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $gzip = [IO.Compression.GZipStream]::new($stream, [IO.Compression.CompressionMode]::Decompress)
    $reader = [IO.StreamReader]::new($gzip, [Text.Encoding]::UTF8)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose(); $stream.Dispose() }
}

function Write-Json([string]$Path, $Value) {
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 16), $utf8)
}

function To-Hiragana([string]$Text) {
    return -join ($Text.ToCharArray() | ForEach-Object {
        if ([int]$_ -ge 0x30a1 -and [int]$_ -le 0x30f6) { [char]([int]$_ - 0x60) } else { $_ }
    })
}

function To-Katakana([string]$Text) {
    return -join ($Text.ToCharArray() | ForEach-Object {
        if ([int]$_ -ge 0x3041 -and [int]$_ -le 0x3096) { [char]([int]$_ + 0x60) } else { $_ }
    })
}

$kanjidicPath = Get-Source 'https://www.edrdg.org/kanjidic/kanjidic2.xml.gz' 'kanjidic2.xml.gz'
$jmdictPath = Get-Source 'https://www.edrdg.org/pub/Nihongo/JMdict_e.gz' 'JMdict_e.gz'
[xml]$kanjidic = Read-Gzip $kanjidicPath
$rankedKanji = @($kanjidic.kanjidic2.character | Where-Object { $_.misc.freq -and [int]$_.misc.freq -le 100 } | Sort-Object { [int]$_.misc.freq })
if ($rankedKanji.Count -ne 100) { throw 'KANJIDIC2 does not contain exactly 100 distinct frequency ranks from 1 to 100.' }
$seedRows = @(Import-Csv -LiteralPath (Join-Path $curriculumDirectory 'kanji_seeds.psv') -Delimiter '|' -Encoding UTF8)
if ($seedRows.Count -ne 100) { throw 'Exactly 100 reviewed seed entries are required.' }
$seeds = @{}
foreach ($seed in $seedRows) {
    if ($seeds.ContainsKey($seed.glyph)) { throw "Duplicate seed: $($seed.glyph)" }
    $seeds[$seed.glyph] = $seed
}

# Stream the dictionary: only retain IDs/readings for the 100 selected examples.
# DTD parsing resolves JMdict's internal part-of-speech entities; external I/O is disabled.
$contextWords = @{}
foreach ($seed in $seedRows) { $contextWords[$seed.contextWord] = $true }
$dictionaryMatches = @{}
$readerSettings = [Xml.XmlReaderSettings]::new()
$readerSettings.DtdProcessing = [Xml.DtdProcessing]::Parse
$readerSettings.XmlResolver = $null
$jmdictStream = [IO.File]::OpenRead($jmdictPath)
$jmdictGzip = [IO.Compression.GZipStream]::new($jmdictStream, [IO.Compression.CompressionMode]::Decompress)
$xmlReader = [Xml.XmlReader]::Create($jmdictGzip, $readerSettings)
$jmdictCreationDate = ''
try {
    while ($xmlReader.Read()) {
        if ($xmlReader.NodeType -eq [Xml.XmlNodeType]::Comment -and $xmlReader.Value -match 'JMdict created: (\d{4}-\d{2}-\d{2})') { $jmdictCreationDate = $Matches[1] }
        if ($xmlReader.NodeType -ne [Xml.XmlNodeType]::Element -or $xmlReader.Name -ne 'entry') { continue }
        $subtree = $xmlReader.ReadSubtree()
        $entry = [Xml.XmlDocument]::new()
        try { $entry.Load($subtree) } finally { $subtree.Dispose() }
        $entryWords = @($entry.SelectNodes('/entry/k_ele/keb') | ForEach-Object { $_.InnerText })
        foreach ($word in $entryWords) {
            if (-not $contextWords.ContainsKey($word)) { continue }
            foreach ($reading in $entry.SelectNodes('/entry/r_ele')) {
                $restrictions = @($reading.SelectNodes('re_restr') | ForEach-Object { $_.InnerText })
                if ($restrictions.Count -gt 0 -and $restrictions -notcontains $word) { continue }
                $key = "$word|$($reading.SelectSingleNode('reb').InnerText)"
                $dictionaryMatches[$key] = $entry.SelectSingleNode('/entry/ent_seq').InnerText
            }
        }
    }
} finally { $xmlReader.Dispose(); $jmdictGzip.Dispose(); $jmdictStream.Dispose() }

$items = [Collections.Generic.List[object]]::new()
$basicRows = @(
    'あ い う え お|a i u e o',
    'か き く け こ|ka ki ku ke ko',
    'さ し す せ そ|sa shi su se so',
    'た ち つ て と|ta chi tsu te to',
    'な に ぬ ね の|na ni nu ne no',
    'は ひ ふ へ ほ|ha hi fu he ho',
    'ま み む め も|ma mi mu me mo',
    'や ゆ よ|ya yu yo',
    'ら り る れ ろ|ra ri ru re ro',
    'わ を ん|wa o n'
)
$voicedRows = @(
    'が ぎ ぐ げ ご|ga gi gu ge go',
    'ざ じ ず ぜ ぞ|za ji zu ze zo',
    'だ ぢ づ で ど|da ji zu de do',
    'ば び ぶ べ ぼ|ba bi bu be bo',
    'ぱ ぴ ぷ ぺ ぽ|pa pi pu pe po'
)
$contractedRows = @(
    'きゃ きゅ きょ|kya kyu kyo',
    'しゃ しゅ しょ|sha shu sho',
    'ちゃ ちゅ ちょ|cha chu cho',
    'にゃ にゅ にょ|nya nyu nyo',
    'ひゃ ひゅ ひょ|hya hyu hyo',
    'みゃ みゅ みょ|mya myu myo',
    'りゃ りゅ りょ|rya ryu ryo',
    'ぎゃ ぎゅ ぎょ|gya gyu gyo',
    'じゃ じゅ じょ|ja ju jo',
    'びゃ びゅ びょ|bya byu byo',
    'ぴゃ ぴゅ ぴょ|pya pyu pyo'
)
$aliases = @{
    'し' = @('si'); 'ち' = @('ti'); 'つ' = @('tu'); 'ふ' = @('hu');
    'じ' = @('zi'); 'ぢ' = @('di', 'zi'); 'づ' = @('du'); 'を' = @('wo');
    'しゃ' = @('sya'); 'しゅ' = @('syu'); 'しょ' = @('syo');
    'ちゃ' = @('tya', 'cya'); 'ちゅ' = @('tyu', 'cyu'); 'ちょ' = @('tyo', 'cyo');
    'じゃ' = @('jya', 'zya'); 'じゅ' = @('jyu', 'zyu'); 'じょ' = @('jyo', 'zyo')
}
$cues = @{
    'お' = 'The regular vowel o (not the object particle).';
    'を' = 'The object-particle character, pronounced o; also romanized wo.';
    'じ' = 'The voiced form of shi (the sa row).';
    'ぢ' = 'The voiced form of chi (the ta row).';
    'ず' = 'The voiced form of su (the sa row).';
    'づ' = 'The voiced form of tsu (the ta row).'
}
$shapeAliases = @{ 'カ' = @('力'); '力' = @('カ'); 'ヘ' = @('へ'); 'へ' = @('ヘ'); 'ロ' = @('口'); 'ニ' = @('二'); '二' = @('ニ'); 'エ' = @('工'); 'タ' = @('夕'); '一' = @('ー'); 'ハ' = @('八'); '八' = @('ハ') }
foreach ($script in @('hiragana', 'katakana')) {
    $order = 0
    foreach ($group in @(@{ Name = 'basic'; Rows = $basicRows }, @{ Name = 'voiced'; Rows = $voicedRows }, @{ Name = 'contracted'; Rows = $contractedRows })) {
        foreach ($row in $group.Rows) {
            $parts = $row.Split('|')
            $glyphs = $parts[0].Split(' ')
            $romaji = $parts[1].Split(' ')
            for ($index = 0; $index -lt $glyphs.Count; $index++) {
                $hiragana = $glyphs[$index]
                $glyph = if ($script -eq 'katakana') { To-Katakana $hiragana } else { $hiragana }
                $order++
                $unicodeId = -join ($glyph.ToCharArray() | ForEach-Object { ([int]$_).ToString('x4') })
                $items.Add([ordered]@{
                    id = "$script-$unicodeId"; script = $script; glyph = $glyph; romaji = $romaji[$index];
                    romajiAliases = @($aliases[$hiragana] | Where-Object { $_ });
                    meaning = "$($group.Name) $script"; productionCue = $cues[$hiragana];
                    order = $order; group = $group.Name; gateRequired = $true; contextual = $false;
                    drawingAliases = @($shapeAliases[$glyph] | Where-Object { $_ })
                })
            }
        }
    }
    $smallTsu = if ($script -eq 'katakana') { 'ッ' } else { 'っ' }
    $word = if ($script -eq 'katakana') { 'カップ' } else { 'きって' }
    $sound = if ($script -eq 'katakana') { 'kappu' } else { 'kitte' }
    $wordMeaning = if ($script -eq 'katakana') { 'cup' } else { 'postage stamp' }
    $items.Add([ordered]@{
        id = "$script-small-tsu"; script = $script; glyph = $smallTsu; romaji = $sound; romajiAliases = @();
        meaning = 'A small tsu marks a brief stop before the following consonant, not a standalone tsu sound.';
        contextWord = $word; contextReading = To-Hiragana $word; contextMeaning = $wordMeaning;
        productionCue = "Write only the small pause character in $sound ($wordMeaning), not the whole word.";
        order = 105; group = 'contextual'; gateRequired = $false; contextual = $true; drawingAliases = @()
    })
}
$items.Add([ordered]@{
    id = 'katakana-long-vowel'; script = 'katakana'; glyph = 'ー'; romaji = 'koohii'; romajiAliases = @('kōhī', 'ko-hi-');
    meaning = 'The long-vowel mark extends the preceding vowel. In koohii both o and i are long.';
    contextWord = 'コーヒー'; contextReading = 'こーひー'; contextMeaning = 'coffee';
    productionCue = 'Write only the long-vowel mark in koohii (coffee), not the whole word.';
    order = 106; group = 'contextual'; gateRequired = $false; contextual = $true; drawingAliases = @('一')
})

$dictionaryEvidence = [Collections.Generic.List[object]]::new()
for ($index = 0; $index -lt $rankedKanji.Count; $index++) {
    $character = $rankedKanji[$index]
    $glyph = [string]$character.literal
    if (-not $seeds.ContainsKey($glyph)) { throw "Top-100 kanji has no reviewed seed: $glyph" }
    $seed = $seeds[$glyph]
    $rank = [int]$character.misc.freq
    if ($rank -ne ($index + 1)) { throw "Missing or duplicate rank: $rank" }
    $readings = @($character.SelectNodes('reading_meaning/rmgroup/reading[@r_type="ja_on" or @r_type="ja_kun"]') | ForEach-Object { (To-Hiragana $_.InnerText).Trim('-').Split('.')[0] })
    if ($readings -notcontains $seed.readingKana) { throw "Reading $($seed.readingKana) not found in KANJIDIC2 for $glyph" }
    $dictionaryKey = "$($seed.contextWord)|$($seed.contextReading)"
    if (-not $dictionaryMatches.ContainsKey($dictionaryKey)) { throw "Example not found in JMdict: $dictionaryKey" }
    if (-not $seed.contextWord.Contains($glyph)) { throw "Context does not contain $glyph" }
    $unicodeId = ([int][char]$glyph).ToString('x4')
    $items.Add([ordered]@{
        id = "kanji-$unicodeId"; script = 'kanji'; glyph = $glyph; romaji = ''; romajiAliases = @();
        readingKana = $seed.readingKana; meaning = $seed.meaning;
        contextWord = $seed.contextWord; contextReading = $seed.contextReading; contextMeaning = $seed.contextMeaning;
        contextHighlightStart = $seed.contextWord.IndexOf($glyph); contextHighlightLength = 1;
        order = $rank; frequencyRank = $rank; group = 'common-kanji'; gateRequired = $false; contextual = $false;
        drawingAliases = @($shapeAliases[$glyph] | Where-Object { $_ })
    })
    $dictionaryEvidence.Add([ordered]@{
        glyph = $glyph; frequencyRank = $rank; contextWord = $seed.contextWord; contextReading = $seed.contextReading;
        jmdictEntryId = $dictionaryMatches[$dictionaryKey]; readingKana = $seed.readingKana
    })
}

$kanjivgCommit = '70a0b7ae0c18ceb5cb358274b029cce0234a43bc'
if (-not $SkipStrokes) {
    $archivePath = Get-Source "https://codeload.github.com/KanjiVG/kanjivg/zip/$kanjivgCommit" 'kanjivg.zip'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $required = @{}
        foreach ($item in $items) { foreach ($character in $item.glyph.ToCharArray()) { $required[([int]$character).ToString('x5') + '.svg'] = $true } }
        $found = @{}
        foreach ($entry in $archive.Entries) {
            if ($entry.FullName -notmatch '/kanji/([^/]+\.svg)$') { continue }
            $name = $Matches[1]
            if (-not $required.ContainsKey($name)) { continue }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $strokeDirectory $name), $true)
            $found[$name] = $true
        }
        foreach ($name in $required.Keys) { if (-not $found.ContainsKey($name)) { throw "KanjiVG lacks expected diagram $name" } }
    } finally { $archive.Dispose() }
}

foreach ($item in $items) {
    foreach ($character in $item.glyph.ToCharArray()) {
        $strokeFile = Join-Path $strokeDirectory (([int]$character).ToString('x5') + '.svg')
        if (-not (Test-Path -LiteralPath $strokeFile)) { throw "Missing stroke file $strokeFile" }
    }
}
if ($items.Count -ne 311) { throw "Expected 311 items, got $($items.Count)" }
foreach ($script in @('hiragana', 'katakana')) {
    foreach ($group in @(@{ Name = 'basic'; Count = 46 }, @{ Name = 'voiced'; Count = 25 }, @{ Name = 'contracted'; Count = 33 })) {
        $count = @($items | Where-Object { $_.script -eq $script -and $_.group -eq $group.Name }).Count
        if ($count -ne $group.Count) { throw "Unexpected $script $($group.Name) count: $count" }
    }
}
$duplicates = @($items | Group-Object { $_.id } | Where-Object Count -ne 1)
if ($duplicates.Count -gt 0) { throw "Duplicate curriculum identifiers: $($duplicates.Name -join ', ')" }

Write-Json (Join-Path $curriculumDirectory 'items.json') ([ordered]@{ version = 1; items = $items.ToArray() })
Write-Json (Join-Path $curriculumDirectory 'dictionary_evidence.json') $dictionaryEvidence.ToArray()
Write-Json (Join-Path $curriculumDirectory 'sources.json') ([ordered]@{
    schemaVersion = 1; reviewedOn = '2026-10-16';
    kanjidic2 = [ordered]@{
        url = 'https://www.edrdg.org/kanjidic/kanjidic2.xml.gz'; dateOfCreation = [string]$kanjidic.kanjidic2.header.date_of_creation;
        databaseVersion = [string]$kanjidic.kanjidic2.header.database_version; sha256 = (Get-FileHash $kanjidicPath -Algorithm SHA256).Hash.ToLowerInvariant();
        license = 'CC-BY-SA-4.0'; ranking = 'Newspaper frequency ranks supplied by KANJIDIC2; not a universal ordering of everyday spoken Japanese.'
    };
    jmdict = [ordered]@{ url = 'https://www.edrdg.org/pub/Nihongo/JMdict_e.gz'; dateOfCreation = $jmdictCreationDate; sha256 = (Get-FileHash $jmdictPath -Algorithm SHA256).Hash.ToLowerInvariant(); license = 'CC-BY-SA-4.0' };
    kanjivg = [ordered]@{ url = 'https://github.com/KanjiVG/kanjivg'; commit = $kanjivgCommit; license = 'CC-BY-SA-3.0'; changes = 'None. Selected original SVG files are bundled unchanged.' }
})
Write-Host "Validated and wrote $($items.Count) learning items, 100 dictionary-backed kanji examples, and all glyph diagrams."
