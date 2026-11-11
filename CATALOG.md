# Bundled Forever catalogs

`AzerMind_Data` and its ItemDetails, QuestDetails and World modules ship alongside `AzerMind` in the same release ZIP. Opening a database loads only the lightweight search index. Detailed entity records and world source lookups load on first hover/attachment, outside combat, and stay cached for the session. It does not depend on Questie being enabled, the companion bridge, an HTTP service, or runtime downloads.

Both item and quest pickers use 25 entries per page with Previous/Next controls. Selection persists across pages; changing filters returns to page one. Item Select page adds the current page, Select filtered applies to all matching pages. Only viewport rows are instantiated, filtered results are cached between scrolling and page changes, and search input is debounced for 150 ms. The item index does not query the client for every entry: only displayed/selected entries receive client enrichment. The first index load can still have a one-time cost; pagination does not make Lua file loading asynchronous.

Both quest tabs provide searchable City and Zone dropdowns. City refers to recorded quest-starter NPC/object locations in the six classic capital areas (1497, 1519, 1537, 1637, 1638, 1657); it is not inferred from the destination, faction, nearest capital or current player position. Unidentified settlements and quests without a recorded capital starter appear under No recorded city. Multiple recorded starting cities are supported. Zone is the quest's positive area ID, with non-geographic categories grouped under Other / unlocated. City selection narrows zone choices. Lists sort by city, zone and title, and location filtering preserves selected quests hidden by filters. Active quests use the live journal headings until the optional lightweight catalog is available; opening their City filter loads only that index. The World/details modules are not needed for location filtering.

## Initial snapshot and coverage

The initial snapshot comes from the locally installed QuestieDB Forever 1.0.12 artifact. `addon/AzerMind_Data/manifest.json` records its commit, SHA-256, entity counts, coverage gaps and validation warnings. The catalog is a historical snapshot, not proof of current live availability. Runtime dynamic corrections are not executed by this importer.

Item classification, names, level requirements, NPC drops, vendors, object sources and quest relationships are included where present. Rarity, icons, equipment slots and stats are supplemented by client data when cached. They are not invented if absent. Rarity/slot filters therefore only match items for which the client knows these fields. Recipe relationships and drop rates are not supplied by this source.

Quest rewards are reverse-indexed from the source's item reward relations, which may be incomplete. NPC/object locations use the source's AreaTable IDs, not guessed map IDs. A displayed coordinate is one recorded spawn, not a route or the only location.

`My items` / `My quests` show character state; database tabs show catalog entries. Catalog entries are not owned items or accepted quests. Active/completed quest status is confirmed from client APIs. Race/class and minimum-level checks can exclude known mismatches but do not establish eligibility; missing prerequisites, reputation and other restrictions leave availability unknown.

## Rebuild

```powershell
npm run catalog:build -- "C:\path\to\QuestieDB"
npm test
.\tools\package-release.ps1
```

Use a baked Forever contract-4 artifact; do not mix expansion flavors. The importer decodes metadata as data and does not execute upstream Lua. It emits Lua files in batches of 1,000 entities, preserves upstream licensing notices, and records added/changed/removed IDs in `build-report.json` using `record-hashes.json`. Rebuilding the same source is deterministic.

Review the source revision, coverage warnings, diff and corresponding source changes before release. Keep source license notices and attribution with the distribution; upstream explicitly documents historical licensing limitations in `SOURCE-LICENSE.md`. This project does not claim that all upstream rights have been cleared. No Questie name/logo branding is used for our addon.

## Validation and release

Automated checks cover metadata chunking, CBOR decoding, Lua serialization, full snapshot loading, custom item 279391, quest 479, manifest counts, conservative quest status, list row reuse and installation of both addon folders.

Before publishing, test in Forever: opening catalogs, search/filter changes, long scrolling, selection, tooltips, attaching references to an existing draft, unavailable item cache, combat loading restrictions and missing-module errors. Check real client load time and memory. Offline Lua tests cannot verify the client's rendering or exact API behavior.

`tools/package-release.ps1` creates a ZIP under `releases/`. Its root contains `AzerMind/`, `AzerMind_Data/` and generated reply-slot addons, ready to extract into `Interface/AddOns`. It also packages transport signals, licensing notices and the catalog importer source. The bridge is installed/run separately. Packaging uses `install-slots.js --addon-dir` with an isolated staging path, never the machine's game configuration. The GitHub workflow **Prepare catalog release** validates and packages; it does not upload to CurseForge. Public release also needs the CurseForge project/version metadata and a real-client check.


## Dungeons and raids

The small `InstancesData.lua` snapshot ships inside AzerMind and does not require ForeverDungeonJournal to be installed or loaded at runtime. Rebuild it with `node tools/build-instances.js PATH_TO_INSTALLED_FOREVERDUNGEONJOURNAL`. The generator parses Lua syntax as data; it does not execute third-party addon code. It extracts factual instance names, reference level ranges, locations/entrance coordinates, boss names and available NPC/item IDs and loot names. It excludes prose descriptions, strategy text, quest prose and art. `InstancesData.json` records the source file checksum and the official raid source URL. Dynamic source corrections are not executed, so coverage is explicitly incomplete.

The three raid entries use Blizzard's raid overview: https://news.blizzard.com/en-gb/article/24303009/world-of-warcraft-forever-raid-overviewlocations-raid-sizes-and-attunement . They preserve announced opening status and known level, location, size and encounter counts. Missing boss names and loot are marked unavailable. No Classic Era raid catalog is assumed to apply to Forever. Catalog IDs are internal link identifiers, never Blizzard instance/map IDs.

The picker offers name/boss/location search, Dungeon/Raid type, location and near-level filters, seven rows per page, and persistent selection across filters. The level range is reference information, not an entry requirement. Right-click previews details; Insert selected adds native AzerMind links to the current draft without sending. On send, those links expand into factual snapshot data. Large loot lists are bounded and labeled partial. Clicking an instance link in chat opens details; Shift-click inserts it into the draft.
