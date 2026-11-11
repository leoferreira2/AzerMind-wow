# Browsing, sources and quest geography — follow-up plan

Status (UI revision 2026-11-11.2): implementation updated against both feedback
lists. Automated behavior is checked separately from live-client verification.
The earlier status only covered dropdowns and AI models; it did not mean the
whole follow-up list had been implemented.

| Step | Current code | Verification / remaining work |
| --- | --- | --- |
| 1. Selector dismissal | Shared toggle and mouse-down handling | Automated regression passes; live pending |
| 2. Entity data | All recorded world spawns and NPC levels retained; itemLevel included in index; regenerated bundled data | Inventory slots/rarity still depend on client cache; source does not supply them |
| 3. NPCs and sources | Mobs & NPCs button in Dungeons & Raids; bounded source browser; name/ID/role/zone search and selectors; item/quest sources; NPC drops/vendors/quest references; coordinate chooser, Map/Add/Copy/URL; visible NPC details button for bosses | Unknown IDs and unmappable zones remain explicit. Visual layout and native map pin need live verification |
| 4. Items | Numeric required-level Min/Max; combinable material/subtype/slot; broader categories; scrollable category list; DB Equipped/Bags/Bank matched by inventory ID; reset and page selection | Unknown metadata can still exclude items from slot/rarity filters. Consumable subtypes follow recorded source classifications |
| 5. Quests | Ready to turn in separated from Active/Completed; per-row map pin and actions; source browser; primary zone ordering; optional capital filter labeled separately | Recorded zones/coordinates can be incomplete; live verification pending |
| 6. Race/class | Independent All/My/specific class and race selectors | Mask predicates tested; does not assert quest availability |
| 7. Settings navigation | Back and close return to Settings; dirty changes remain protected | Automated parent-return check passes; native close/Escape visual check pending |
| 8. Chat list | Scrollbar uses bottom of box; undo footer reserved only while shown | Native scrollbar placement needs live visual check |
| 9. Sounds | Notifications page: None, Whisper, Battle.net toast, Map ping, Ready check, Tutorial popup; preview; persisted global choice | Automated persistence check passes; native playback pending |
| 10. AI models | Provider catalogs and supported reasoning selectors; advanced custom fallback | Existing automated provider/catalog checks pass |
| 11. Integration | Full suite and codec round-trip pass; read-only installed-file verifier added; Settings displays UI revision | In-game appearance and reported Details failure are not certified fixed |
| Additional: chat keys | Settings > Key bindings; open/new actions created at login; conflict checks and saved bindings | Automated login/open/new check passes; native key capture/discovery pending |

### Validation and installation

- Run `npm test` for behavior/parser/transport checks.
- Run `npm run verify:install` after installing/rebuilding. This is read-only and
  compares source Lua/TOC/XML files with the configured game AddOns directory,
  including all four catalog modules. It deliberately excludes transport Inbox.lua.
- Settings should show **UI revision 2026-11-11.2** after the installed code loads.
- These latest edits have not been copied into the protected game directory by
  this session. A comparison made after editing reports differences as expected;
  that is not evidence explaining an earlier failed rebuild.
- The exact cause of the reported live Details failure remains unconfirmed.
  Details now reports its real traceback locally instead of failing silently,
  and avoids retaining a half-built dialog singleton. Do not call it fixed until
  the failing interaction is reproduced successfully in the native client.
- Live acceptance remains open for both plans. No release was published.

## Scope captured from feedback

| Feedback | Intended result |
| --- | --- |
| Clicking an open location filter does not close it | Clicking the same selector toggles its menu closed; applies to all selectors |
| Mobs appear only as names and cannot be browsed/clicked | Structured NPC/boss lists, clickable entity names, NPC details and source locations |
| Where-to-find options are incomplete | Local source/location browsing, map actions, and clearly separate AI questions |
| Cloth cannot be narrowed naturally to legs | Combined category/material/slot browsing with a visible Cloth > Legs path |
| Consumables and other types need sublists | Data-driven category/subcategory navigation for every supported item class |
| Need item level requirement filtering | Explicit required-character-level minimum/maximum, distinct from item level |
| Ashenvale quests appear under No recorded city | Group by quest zone; distinguish zone, starter location and optional city |
| Quest rows need map-pin actions and other useful shortcuts | Per-row location, details and action controls that do not accidentally select the row |
| Race/class only supports my character | Independent Class and Race selectors with All, My character and specific choices |
| Need to filter quests ready for hand-in | Explicit Ready to turn in status, distinct from in-progress and already completed quests |
| Closing a settings subpage closes all settings | Back and close return to the parent Settings screen when opened from it |
| Chat-list bottom scroll arrow floats above the bottom of its box | Align the scrollbar with the usable conversation viewport; reserve footer space only when visible |
| Equipped/Bags/Bank, Reset filters and Select page do not work in Item database | Define database ownership filters against actual inventory IDs and fix/reset-test database actions |
| Required level is a clickable toggle instead of a range | Editable numeric Min/Max inputs, not a cycling control or checkbox |
| Need configurable reply sounds | Settings > Notifications with five built-in sound choices, preview and None |
| AI model switching relies on typing model IDs | Populate model and reasoning dropdowns from researched/provider catalogs; custom IDs remain advanced fallback only |

## Source audit: confirmed constraints

- Theme.ShowChoiceMenu always opens. Its outside-click handler closes the menu
  on mouse-down outside the menu, including the selector; selector click can
  then immediately reopen it. A toggle fix must cover both event paths.
- Items.lua has a short hard-coded category list. Slot is a separate selector,
  and the only level control is a boolean relative to the current character.
- The lightweight item index has requiredLevel, classID and subclassID, but no
  inventory slot. Slot filtering currently relies on client metadata enrichment.
  The importer reads itemLevel into full records but omits it from the search index.
- Items.lua explicitly disables Equipped/Bags/Bank in database mode. Database
  rows represent catalog entries rather than inventory locations, so enabling
  the existing location comparison alone would not implement ownership filtering.
  Reset filters and Select page are not explicitly disabled there; their reported
  failure needs reproduction against actual catalog data and pointer/layout state.
- Catalog.lua formats sources into comma-separated text through Named(), with
  a hard limit of 12 entries. NPCs are not supported in Links.lua's entity kinds.
  Most details open in a selectable copy box, whose text is not an interactive
  entity browser. Formatting hyperlink markup alone will not fix that surface.
- The World module compacts every NPC/object to its first recorded area and
  first coordinate. Additional locations must be preserved before the UI can
  truthfully offer all locations.
- The current city index contains capital-city starters only. Ashenvale is a
  quest zone and need not have a recorded capital-city starter. Those are
  separate facts, not contradictory records.
- Quest masks already exist for requiredClasses and requiredRaces, but the
  browsing predicate only checks the current character. Eligibility/status
  calculation must remain separate from hypothetical class/race browsing.
- Existing quest map functions can resolve objectives/turn-ins and choose
  coordinates. They can be reused; neither area IDs nor NPC IDs may be treated
  as map IDs without the existing conversion/resolution path.
- Instance boss records sometimes lack NPC IDs, and loot sometimes lacks item
  IDs. Missing identifiers must not be invented from names.

## Step 1 — Fix shared dropdown dismissal (P0)

Files: Theme.lua, shared-menu callers, addon tests.

1. Treat the active selector as part of the open menu's interaction region.
2. Clicking that same selector closes the menu, clears menu-search focus and
   preserves the selected value, filter state and results.
3. Clicking another selector switches the menu owner and choices directly.
4. Selecting a row closes the menu and applies exactly one change. Escape,
   outside click, scrollbars and hidden-parent behavior remain consistent.
5. Cover mouse-down followed by click, not just a second function invocation.

Acceptance: open -> click the same selector -> closed, with no reopen flicker;
works for city, zone, instance location, rarity, slot and quest status. Search,
keyboard selection and fit/scaling behavior remain intact.

## Step 2 — Establish structured entity and source data (P0)

Files: Catalog.lua, build-catalog.js, generated catalog modules, Links.lua.

- Add adapters returning typed records rather than display strings:
  entity kind/ID/name, role, level range when known, source relation, zone,
  map ID when resolved, coordinates, provenance and missing-data state.
- Preserve NPC/object spawn locations across all recorded areas. Maintain a
  small browsing index and lazy-load detailed location pages/chunks; avoid
  moving every full record into the startup index.
- Preserve required level and item level as distinct index fields. Establish
  a reliable inventory-slot field from an authoritative compatible source if
  available; otherwise retain an explicit unknown value and cache coverage.
- Keep class/subclass identities as IDs. Resolve display labels independently
  so localization and missing client cache cannot break filtering.
- Derive known vendor, quest-giver and drop-source roles from recorded
  relationships. Do not label every NPC a hostile mob or infer hostility from
  the presence of an item drop alone.
- Retain catalog version/layout checks, provenance and generation validation.
  Display incomplete coverage honestly; unknown is not zero, unavailable or
  proof that no source exists. Never invent drop percentages.

Acceptance: a fixture with two zones and several coordinates retains them
all after generation/loading; slot/level values survive indexing; incomplete
records remain browsable and do not produce fabricated map points.

## Step 3 — NPCs, bosses and Where to find (P1)

Files: new reusable entity/details view, Catalog.lua, Links.lua, Instances.lua,
Items.lua, Map.lua; a bounded NPC browsing index if required by dataset size.

- Add a Mobs & NPCs browser with search, zone and known-role filters,
  pagination and bounded rows. Search by name or exact NPC ID.
- Make NPCs/bosses in quest objectives, item drops/vendors, and instance
  details open the same entity view. Use addon-owned NPC links with explicit
  IDs; generic native SetItemRef is not a sufficient NPC implementation.
- Replace plain-text source details with structured sections: Drops from,
  Sold by, Quest rewards, Objects and other recorded sources. Each section
  has a count, rows and pagination instead of silently stopping at 12 names.
- NPC view: name, ID, recorded role/level when available, zone/location list,
  relevant quest/item references, Map, Add to message, Copy and external URL.
- Where to find opens known local sources first. Separate **Ask AI where to
  find it** from database actions; AI actions add a draft and never auto-send.
- Multiple locations open a chooser labeled with zone and coordinates.
  Show one selected source on the map, with optional navigation and clear/remove.
- Unknown ID: show the name and a details state explaining missing data; allow
  name-based AI drafting, but no guessed entity hyperlink or precise map action.
- Keep copy as a separate action over readable text. Copy boxes remain plain
  selectable text, not the surface used for interactive entity navigation.

Acceptance: an item -> drop NPC -> location -> map flow works without asking
AI or sending a message. Bosses with IDs work identically; missing IDs/spawns
produce an explicit explanation, never a dead clickable label.

## Step 4 — Complete item taxonomy and level ranges (P1)

Files: Items.lua, Catalog.lua, shared selectors, catalog metadata.

Use combinable facets instead of enumerating every combination as an item
category. Keep the current path visible above results, with clearable facets.

| Category | Subcategories / additional facet |
| --- | --- |
| Armor | Cloth, Leather, Mail, Plate, Shields, other recorded armor subclasses; then compatible equipment slots |
| Weapons | Recorded weapon subclasses, then compatible hand/slot options |
| Accessories | Neck, Rings, Trinkets, Cloaks and other applicable recorded slots |
| Consumables | Recorded subclasses, with useful potion, elixir, food/drink, bandage and other groupings only when supported by data |
| Trade goods/materials | Recorded subclasses; optional profession relationships only when known |
| Recipes | Recorded recipe/profession subclasses |
| Containers | Recorded bag/container subclasses |
| Other item classes | Retain a browsable class/subclass hierarchy; do not hide valid records just because no special UI exists yet |

- Example: **Armor > Cloth > Legs**, combined with rarity and level range.
  The slot selector must offer **Legs** explicitly. Keep Head/Chest/Legs/etc.
  visible for the selected material instead of forcing users to scan Cloth.
- Build options from supported class/subclass metadata and actual records,
  with counts and a useful fallback. Reconcile the friendly taxonomy with
  source IDs before hard-coding consumable groups; sources can group them
  more coarsely than the names suggest.
- Keep Type, Subtype and Slot conceptually separate. Changing a parent resets
  only incompatible child filters and visibly explains that reset.
- Replace the sole player-relative toggle with **Required level: Min–Max**,
  inclusive, optional bounds, plus Any and My level presets.
- Min and Max are editable numeric input fields with persistent labels and
  example values (such as 15 and 25). This is a direct range entry, not a
  click-to-cycle button or a checkbox. Presets only fill/clear these inputs.
- Blank Min or Max means an open bound; blank both means Any. Apply edits
  predictably (Enter or a short debounce after valid input), reset pagination
  when the range changes, and keep the last valid results while showing an
  inline error for invalid text or Min greater than Max. Do not silently swap
  or clamp the entered values. Clearing the range restores all eligible levels.
- Treat item level as a separate optional **Item level: Min–Max** filter, not
  another name for required character level. Label the two values in details.
- Validate inverted/invalid ranges in place; retain the user's other filters.
  Distinguish unrestricted level 0 from missing required-level metadata.
- Unknown slot/level values get an explicit Include unknown option or coverage
  explanation; never silently claim cached-only results are exhaustive.
- Apply the same controls to owned items and the database. Preserve source
  selections, pagination, limits, and Reset filters behavior.
- Define **Ownership** for Item database: All catalog items, Equipped, Bags,
  and Bank snapshot. Intersect catalog IDs with the corresponding inventory
  snapshot, rather than comparing a catalog row's location string to Bags.
  Keep location filtering in My items, where separate physical copies matter.
- Refresh equipped/bag ownership after inventory changes and show bank snapshot
  age. Distinguish **No matching owned items** from **Bank not scanned**.
  Preserve the catalog view's rarity/type/slot/level filters when changing
  ownership, and retain selection using stable source-specific keys.
- Reproduce and fix **Reset filters** and **Select page** in database mode.
  Check click hit areas, overlapping rows/controls, stale query caches and
  selected-only state before assigning a cause. Reset clears all filters,
  numeric range inputs and ownership to All, but preserves selection. Select
  page adds exactly the current filtered page, remains within the active source,
  updates the count immediately and explains an attachment-limit excess.
- With no results, Select page is disabled with a clear empty-result state.
  Neither action may silently do nothing because another hidden filter remains.

Acceptance: Cloth + Legs + required level 15–25 produces only matching known
items; boundary values match inclusively. Consumables have meaningful browsable
subsets where supported; every available item class can be reached. Selecting
an uncached item does not change which known slot/level it matches.
In Item database, Equipped/Bags/Bank ownership matches the recorded inventory
IDs; Reset clears every active facet and range; Select page works on the first,
middle and final partial page. Test selected-only mode, inventory updates,
unscanned/stale bank data and pointer clicks at minimum window/UI scale.

## Step 5 — Correct quest geography and add row actions (P1)

Files: Catalog.lua, Quests.lua, quest-location/map adapters, shared icons.

- Make **Zone** the primary geographic filter and grouping. Show Ashenvale
  under Ashenvale even when no capital-city starter is recorded.
- Move the current city facet to an optional advanced **Starting city** filter;
  rename its empty value to **No recorded capital starter**. Never use it to
  imply the quest has no known location or to hide the known quest zone.
- Distinguish Quest zone, Start, Objective and Turn-in in row metadata/details.
  An objective may span zones or lie outside the quest's index zone; show the
  actual recorded locations in the chooser rather than flattening them.
- Add a reserved action area to every row, without overlapping names/checkboxes:
  **map pin**, **details**, and an overflow menu. Keep the full quest title and
  location available on hover.
- Map pin opens a chooser for Start / Objectives / Turn-in and multiple
  recorded locations. Reuse existing quest marks and coordinate resolution.
  Label the selected purpose in the marker and navigator.
- Overflow: Show in quest log when active, Add to message, Check requirements,
  Copy name/link, and Remove map mark when one exists.
- Show disabled reasons for unavailable coordinates or unavailable quest-log
  actions. A known zone without coordinates can open the zone map, clearly
  labeled **Open zone map**, without inventing a quest pin.
- Row-action clicks must not toggle selection, clear the current filters,
  send messages or navigate the character automatically.
- Apply to both My quests and Quest database. Preserve unknown geography
  instead of replacing it with the player's current zone.
- Add **Ready to turn in** to the quest Status selector. Distinguish **In
  progress**, **Ready to turn in**, **Completed (turned in)**, and unknown or
  restriction states. Keep **Active** as an aggregate of in-progress and ready
  quests where useful; the statuses must not conflate completed objectives
  with a quest already handed in.
- Read readiness from live quest-log completion state, refreshing on quest
  updates. Use the same live state in My quests and Quest database when a
  database quest is in the player's log. Do not infer readiness from catalog
  objectives, character level or historical completion flags. Missing live
  state remains unknown, and failed quests must not match Ready to turn in.
- Show a checkmark and **Ready to turn in** in matching row metadata; its map
  pin should default to recorded turn-in locations, with other purposes still
  available. Missing turn-in coordinates get the existing disabled explanation
  or explicitly labeled zone-map fallback.

Acceptance: an Ashenvale quest with no capital starter is easy to find by zone;
its row offers applicable map actions. Multi-zone objectives, missing coordinates,
active/completed quests, and map-mark removal have clear outcomes.
The Ready to turn in filter includes quests with completed objectives still in
the log, excludes in-progress, failed and already handed-in quests, updates
after progress/turn-in events, and behaves consistently in both quest sources.

## Step 6 — Explicit class and race browsing (P1)

Files: Quests.lua, Catalog.lua, shared selectors, tests.

- Replace the combined My character toggle with separate **Class** and **Race**
  selectors: All, My character, and each class/race supported by this client/data.
- Start with single explicit selections for predictable behavior. Class and
  race combine with AND. Keep a My character preset to set both together.
- Include unrestricted quests when browsing a specific class/race. Separate
  unknown restriction data from verified unrestricted records.
- Evaluate recorded masks against the selected IDs rather than the current
  player. Obtain supported names/IDs from compatible metadata; do not assume
  the retail class/race roster applies to Forever.
- Keep **Status for my character** separate: browsing another class does not
  change the current player's actual eligibility or completion state.
- Apply to both sources when restrictions are known; otherwise show unknown
  requirements explicitly. Persist selected values and reset them predictably.

Acceptance: choosing Warlock while playing another class yields Warlock and
unrestricted quests, excludes known class conflicts, and does not falsely
label them available to the current player. Equivalent race and combined tests pass.

## Step 7 — Settings subpage navigation (P1)

Files: Settings.lua, shared dialog/navigation helpers, addon tests.

- Track the settings page's actual entry point. Opening Guide references or
  Character context from Settings establishes Settings as its parent; opening
  either directly from the composer does not invent a parent settings screen.
- Add a visible **Back to Settings** action to subpages opened from Settings.
  Back, the subpage's close X, and Escape dismissal return to Settings rather
  than closing the entire settings flow. An Escape consumed by an input to
  release focus does not also dismiss or navigate a page.
- Preserve the parent conversation, defaults/conversation scope and other
  relevant navigation state. Return focus sensibly without stealing input
  into the message composer behind the open Settings screen.
- Preserve unsaved-change protection: attempting to leave a dirty subpage
  offers **Discard and go back** or **Keep editing**. Cancel discards edits
  and returns to the parent; pending saves retain their existing safeguards.
- After a successful Save, provide clear feedback and keep Back available.
  Do not silently close the parent screen. Directly opened pages close back
  to their caller instead of reopening Settings unexpectedly.
- Only closing the root Settings panel exits the settings flow. Hiding or
  minimizing the main chat is not a request to reopen Settings or a subpage.
- Reuse one explicit navigation mechanism rather than unrelated callbacks
  that hide/show panels. Prevent stale return targets and recursive close
  handlers when switching conversations, reopening pages or discarding edits.

Acceptance: Settings -> Guide references -> X returns to the same Settings
screen; Back and Escape dismissal behave consistently. Repeat for Character
context, saved/dirty/pending states and direct entry. No lost unsaved edits,
phantom windows, unintended composer focus or unexpected settings reopening.

## Step 8 — Conversation-list scrollbar alignment (P1)

Files: AzerMind.lua, sidebar layout/scroll controls, addon tests.

- Confirmed source finding: the conversation scroll frame always reserves
  44 units at the bottom for Undo deletion, even while that button is hidden.
  This can leave the scrollbar's bottom arrow visibly above the panel bottom.
- Give the conversation viewport and its scrollbar the same top/bottom bounds.
  With Undo hidden, use the normal bottom inset instead of an empty footer.
- When Undo is visible, reserve a clearly separated footer and anchor the
  scrollbar to the actual list viewport above it. Alternatively move Undo to
  a non-conflicting notification area; do not leave an unexplained blank band.
- Update the layout when Undo appears/disappears, the chat switches, history
  is restored, or the window is resized. Keep controls inside the box and
  ensure the last conversation can scroll fully into view.
- Base scroll range on actual visible row content, clamp it after deletions or
  resize, and preserve the reading position where possible. Disable arrows
  when the corresponding direction has no remaining content.
- Inspect the native scrollbar template's own arrow offsets in game before
  adjusting them; do not compensate blindly by pushing the entire frame.

Acceptance: the lower arrow sits at the bottom of the usable list, with no
unexplained gap while Undo is hidden. The last chat remains reachable with
one/many chats, Undo on/off, switching conversations and minimum/expanded
window sizes. Arrows and rows do not overlap the footer or panel border.

## Step 9 — Notification sound settings (P1)

Files: Settings.lua, AzerMind.lua notification path, saved settings migration,
shared selector/preview components, addon tests.

Current behavior: AzerMind.Notify calls PlaySound(3081) directly for replies.
Replace this notification choice without modifying the bridge's separate
sound-file readiness/presence transport checks or map arrival feedback.

### Researched shortlist

These names and IDs were verified against Blizzard UI SoundKitConstants.lua
in the public wow-ui-source mirror. They are candidates for Forever, not a
claim that every candidate has been auditioned or verified on this client.

| UI label | SOUNDKIT constant | SoundKit ID | Suggested role |
| --- | --- | --- | --- |
| Whisper (current default) | TELL_MESSAGE | 3081 | Preserve familiar existing message feedback |
| Battle.net notification | UI_BNET_TOAST | 18019 | Alternative notification cue; first alternative to audition |
| Map ping | MAP_PING | 3175 | Compact familiar cue; user may prefer a sound distinct from map activity |
| Ready check | READY_CHECK | 8960 | More noticeable option for replies while the window is minimized |
| Tutorial notification | TUTORIAL_POPUP | 7355 | Another native UI notification candidate |

Source: [Blizzard UI sound constants](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Mainline/SoundKitConstants.lua).
The shortlist is a design recommendation based on the sounds' UI roles;
final subjective loudness/pleasantness requires in-game preview.

### Configuration and behavior

- Add **Notifications** under Settings, respecting Back/close behavior from
  Step 7. Scope: all conversations on this addon profile, independent of AI provider.
- **Reply sound** selector: the five candidates above plus **None (mute)**.
  Resolve the selected SOUNDKIT constant when available and use its verified
  numeric fallback where appropriate. Never pass an invented identifier.
- Add a separate **Preview** action. Selecting an option alone does not
  surprise the user with repeated playback; preview does not send a message,
  alter the conversation or change the saved value before Save.
- Default to Whisper to preserve behavior for existing installations. Persist
  stable preset keys and migrate absent/invalid settings safely. None skips
  the notification call entirely; it must not disable transport readiness checks.
- Channel selector: **Sound effects** by default, with an explicit **Master**
  alternative if supported. Respect the game's volume/mute configuration.
  Explain the channel instead of promising independent per-addon volume or
  changing global sound CVars. A per-addon volume slider requires a supported
  playback path and is outside the first version.
- Optional **Only when this conversation is not visible** checkbox, default
  off to retain current behavior. Preview remains available independently.
- Playback failure should not interrupt delivery/rendering. Report an
  unavailable preset during preview and offer Whisper fallback; do not silently
  claim the selected sound played. Bound rapid previews and deduplicate reply
  notifications so chunked/duplicate responses cannot spam the selected sound.

Acceptance: preview all candidates on the actual Forever client; save/reload
retains the preset/channel; None is silent; existing profiles retain Whisper;
only final new replies notify once; transport sound probes and map arrival
notifications remain unaffected. Test muted channels, unavailable kits,
duplicate replies, hidden/visible conversation preference and settings Back.

## Step 10 — Populate AI model and reasoning choices (P1)

Files: bridge/codex-settings.js, bridge/agents.js, provider catalog adapters,
metadata transport, Settings.lua, provider/addon tests.

### Pre-implementation findings from source, installed tools and official documentation

- Only Codex currently supplies an automatically populated model catalog.
  Other providers depend on manually configured model arrays. The UI puts
  Enter model ID near the top, so the fallback appears to be the normal flow.
- Reasoning capabilities are currently hard-coded per provider, which can
  over-advertise settings for one model and hide valid settings for another.
  Grok is hard-coded to no reasoning, despite current official CLI support;
  Antigravity's global list omits xhigh, and Hermes' list omits max/ultra.
  These are potential capabilities, not a reason to enable them on every model.
- The installed Claude Code is 2.1.161. Its own help accepts low, medium,
  high, xhigh and max and documents sonnet/opus aliases and a pinned
  claude-opus-4-8 example. Newer online documentation is not proof that a new
  model/alias or capability is available to this installed version/account.
- Codex's local catalog is populated. Use it as the account-specific source;
  do not replace it with a public API model list or another user's catalog.
- Grok, Antigravity and Hermes were not on this environment's command PATH
  during the check. Discover their configured executable paths before calling
  them unavailable. No installs, sign-ins, paid inference or configuration
  changes were performed during research.

### Researched choices and authoritative discovery

| Agent | Dropdown population | Reasoning rules |
| --- | --- | --- |
| Codex | Existing account-local model catalog; retain discovered names/IDs | Use each row's supported_reasoning_levels |
| Claude Code | Documented Opus, Sonnet and Haiku aliases as useful built-in choices; merge available account/version-specific pinned models | Derive supported efforts from the resolved model and installed CLI; preserve Automatic |
| Grok | Current official CLI documents grok models; use installed-version-compatible discovery rather than guessing from the API product list | Current CLI documents --effort; verify the installed version, then read per-model effort capabilities |
| Antigravity | Official CLI documents agy models, returning selectable slugs | Use actual variants; low/medium/high and optional xhigh/max depend on the model |
| Hermes | Use authenticated-provider curated catalogs exposed by its supported local catalog interface | Read provider-route/model reasoning metadata; not every model supports reasoning or every effort |

**Codex choices observed locally** (these seed the UI on this machine, not a
hard-coded entitlement list for every installation):

| Model ID | Observed efforts |
| --- | --- |
| gpt-6.1-sol | low, medium, high, xhigh, max, ultra |
| gpt-6-astra | low, medium, high, xhigh, max, ultra |
| gpt-6.1-terra | low, medium, high, xhigh, max, ultra |
| gpt-6-sol | low, medium, high, xhigh, max, ultra |
| gpt-6-luna | low, medium, high, xhigh, max |
| gpt-5.6-sol | low, medium, high, xhigh, max, ultra |
| gpt-5.6-terra | low, medium, high, xhigh, max, ultra |
| gpt-5.6-luna | low, medium, high, xhigh, max |

**Other documented examples** are research seeds, not confirmed entitlements:

- Claude: aliases opus, sonnet, haiku; the current docs resolve aliases
  differently by backend. They describe low/medium/high/xhigh/max on newer
  models, with older 4.6 entries lacking xhigh. Prefer account/version discovery
  over pinning every user to the latest published version.
- Antigravity: documented CLI examples include gemini-4-argon-high,
  gemini-4-argon-medium, gemini-3.8-flash-high and gemini-3.8-flash-medium.
  Populate the actual agy models output; collapse a family into Model + Effort
  only when its metadata provides an unambiguous mapping. Otherwise display
  the exact variant, with no conflicting extra effort override.
- Hermes: a provider route can expose IDs such as
  anthropic/claude-opus-4.7 or google/gemini-2.5-flash. Its documented model
  options endpoint lists authenticated providers and curated agent models.
  Do not display every provider's public catalog as if it were configured.

### Implementation contract

1. Add a cached, refreshable provider catalog adapter with model ID, friendly
   name, supported effort IDs/labels, discovery source, freshness and CLI
   version. Keep discovery read-only; never launch an interactive model
   picker, change the provider's saved default or start an AI turn to list models.
2. Prefer authenticated local/runtime discovery; use a dated, researched
   bundled compatibility catalog only as fallback, clearly identified as
   unverified for the current account. Include documented common choices,
   not an empty dropdown requiring the user to type everything.
3. Preserve explicitly configured deployment/custom IDs alongside the standard
   list. Keep **Custom model...** under an advanced/fallback action at the end.
   Research-based defaults do not remove valid custom routing.
4. Bound discovery time and returned list sizes; cache last-good results and
   retain the selected model if refresh fails. Distinguish unavailable provider,
   login required, stale catalog and unsupported discovery. Do not expose tokens,
   endpoint credentials or unrelated configuration in metadata sent to WoW.
5. Use a searchable, scrollable model selector with friendly labels and exact
   IDs available on hover. The current settings dropdown sizes itself to every
   row; replace that path before introducing hundreds of models.
6. Model selection updates the reasoning selector to that model's exact supported
   options. Unsupported effort clears to Automatic with an explanation. Hide
   or disable reasoning with a reason when the model has no adjustable effort.
   Unknown capability is not equivalent to supporting the provider's entire union.
7. Validate and serialize the selected capability correctly for each installed
   CLI. Update Grok effort forwarding only when that version supports it;
   resolve Antigravity base/variant semantics; support Hermes' actual route.
   Do not silently translate arbitrary effort values across providers.
8. Keep global defaults and per-conversation overrides, inheritance, saved
   provider-specific selections, pending acknowledgements and Back navigation.
   Show when a model change applies and whether a fresh provider session is
   necessary; do not imply an in-flight response switches model mid-turn.
9. Include a Refresh models action handled through the bridge. No HTTP access
   from the addon itself. Version the metadata contract if its shape changes.

Acceptance: every configured supported agent offers useful discovered or
clearly labeled compatibility choices without hand-entering names. Reasoning
changes correctly with the model; invalid combinations cannot be saved. Verify
offline/stale discovery, unavailable CLI, login/account restrictions, custom
deployments, long catalogs, refresh, variant mapping and existing overrides.

### Primary research references

- [Claude Code model configuration](https://code.claude.com/docs/en/model-config)
- [Grok CLI reference](https://docs.x.ai/build/cli/reference)
- [Grok per-model configuration](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-pager/docs/user-guide/26-config-reference.md)
- [Antigravity headless model selection](https://antigravity.google/docs/cli/headless/)
- [Antigravity effort levels](https://antigravity.google/docs/cli/commands/effort)
- [Hermes model configuration and discovery](https://hermes-agent.nousresearch.com/docs/user-guide/configuring-models)
- Local evidence: current Codex catalog adapter output and installed Claude
  Code --version/--help. These document observations, not a permanent public
  model roster; recheck discovery at implementation time.

## Step 11 — Integration and validation (P1)

- Test the complete chain: item category -> subtype -> slot -> required level
  -> source NPC -> multiple locations -> map -> add reference to draft.
- Test quest zone -> explicit class/race -> row map chooser -> objective NPC
  -> details, with selection and page state preserved throughout.
- Regression coverage: dropdown event ordering; no accidental sends or row
  selections; ID validation; missing data; unknown masks; inclusive ranges;
  generated index fidelity; full location retention; bounded menus/rows and
  lazy loading; map-mark lifecycle and unrelated user waypoint preservation.
- Verify dependency/module packaging and rebuild requirements after adding
  indexes/details. Avoid eager loading the full world just to open a filter.
- In-game pass at minimum/default/expanded layouts, different UI scales,
  long names, empty/loading/error states, and combat restrictions on lazy loads.
- Add the checked implementation state, actual test results and live observations
  below as each step finishes. Do not mark visual checks complete from source tests.

## Progress tracker

The current step-by-step tracker is the code/verification table at the start of
this document. The original planned acceptance criteria above remain the target,
not a claim that every visual or data-coverage case has been verified.

Latest checks: complete npm suite (163 tests) and codec round-trip passed; after the final
source/map changes, all 79 addon/catalog behavior tests passed. Live acceptance
for both plans remains open, especially the reported Details failure.
