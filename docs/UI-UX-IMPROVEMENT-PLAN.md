# UI/UX readability and interaction plan

Status: implementation in progress. The table below separates automated checks
from live-client validation. Existing unrelated project changes are preserved.

| Phase | Code progress | Validation |
| --- | --- | --- |
| 1. Shared controls | Implemented: shared labeled/searchable selectors, keyboard menus, checkbox toggles, semantic icons, search fields, tooltip/primary actions, dialog fitting and dirty-change protection | Automated checks pass; live visual sign-off pending |
| 2. Pickers | Implemented: explicit dropdowns, numeric required-level Min/Max inputs, additive page/all-result selection, source-specific selection, reset/selected-only behavior, attachment labels/limits, source refresh reconciliation and full-value tooltips | Automated checks pass; live visual sign-off pending |
| 3. Chat | Implemented: larger message actions, local deletion Undo, provider-independent settings access, visible conversation menu, local-history/session-reset distinction, grouped icon actions and reading-position preservation | Automated checks pass; live visual sign-off pending |
| 4. Settings and map | Implemented: persistent scope, dirty-change guard, navigation guard, retained sharing choices, guide counts/line errors/save feedback, navigator Previous/Next/Stop and marker legend tooltip | Automated checks pass; live visual sign-off pending |
| 5. Release verification | Lua/order, complete automated suite, codec round-trip and diff checks run; no publish performed | Live client appearance, scaling, installed-file/reload and keyboard-binding checks remain open |

Latest follow-up work is tracked in [UI-UX-FOLLOWUP-PLAN.md](UI-UX-FOLLOWUP-PLAN.md),
including the code/test/live matrix for UI revision 2026-11-11.2. Neither plan's
live-client acceptance is complete; the reported Details failure is still open.

### Progress log

- [x] Read the current implementation and preserve unrelated work already present.
- [x] Extract the bounded quest-location menu into a shared choice component.
- [x] Adopt explicit selectors for item rarity/slot and quest status.
- [x] Add shared pin and composer icons while retaining text labels.
- [x] Standardize picker selection, level labels, search labels and insertion.
- [x] Add message Undo, larger action targets, session/reset distinctions and scroll preservation.
- [x] Make AI settings accessible for every provider.
- [x] Protect unsaved settings and clarify sharing/guide state.
- [x] Add visible map navigation controls and a marker legend tooltip.
- [x] Add meaningful regression coverage and run the complete suite.
- [x] Update the shared design-system contracts.
- [ ] Verify appearance, contrast, clipping, native textures, focus and combat behavior in the game.
- [ ] Verify minimum/default/expanded layouts at the resolution and UI-scale matrix below.
- [ ] Verify installed files, actual reload/restart behavior and binding discovery in the client.
- [ ] Capture before/after visual sign-off and publish only on a separate authorized request.

### Validation boundary

The complete automated suite passed with **144 tests** and the codec round-trip
checks during this implementation. Additional targeted behavior checks cover
keyboard choice selection, source selection persistence, additive quest selection,
message undo, provider-independent menu access, scroll preservation, unsaved guide
protection and visible navigator controls.

The final complete run passed all 144 tests, Lua/order checks and codec
round-trip checks. The installed Theme.lua hash differs from the updated source,
so a rebuild/reload is required before live validation. The running WoW window
was located, but the desktop connection took several minutes to respond and no
visual inspection was completed. Phase 5 remains open until the validation
matrix is observed on the rebuilt addon. No in-game visual result is claimed.



## Evidence and scope

Reviewed Theme.lua, AzerMind.lua, Items.lua, Quests.lua, Instances.lua,
Settings.lua, Map.lua, Bindings.xml, the existing design-system document,
and the supplied Dungeons & Raids screenshot.

This is a source audit with one visual reference, not a completed in-game
visual audit. Contrast, scaling, texture appearance, clipping, mouse behavior,
and keyboard propagation must be verified on the supported Forever client.
Do not describe those checks as passed until observed.

Preserve the warm charcoal, ivory, gold, and restrained teal treatment.
Keep all product labels in English. Improve existing workflows without
changing the transport protocol or replacing the bundled catalog.

## Findings and decisions

| Area | Evidence / problem | Planned change | Priority |
| --- | --- | --- | --- |
| Shared controls | Similar-looking buttons implement actions, cycling selectors, and toggles | Separate action, dropdown, checkbox, and tab components | P0 |
| Filter meaning | Location needed a persistent label; other selectors need the same rule | Always retain the field name, selected value, and dropdown arrow | P0 |
| Item rarity and slot | Clicking advances to the next value | Replace cycling with option menus; searchable for long lists | P0 |
| Quest status | Clicking cycles through six statuses | Explicit dropdown with current selection | P0 |
| Level filters | Labels can exceed fixed button widths; level meaning differs by screen | Numeric ranges with precise labels: required level vs quest/instance range | P0 |
| Bulk selection | Items add filtered matches; Quests replace the selection | Standardize additive Select page and Select all results; Clear selection is separate | P0 |
| Picker state | Items and Quests clear selection on source changes; filters can hide selections | Independent selection per source; preserve across filters/pages; explicit Clear | P0 |
| Selected-only mode | Selected (N) can mean either count or action | Checkbox labeled Show selected only; count displayed separately | P0 |
| AI settings discovery | Conversation menu still gates AI settings on Codex | Show settings for every provider; gate individual capabilities using provider metadata | P0 |
| Deletion semantics | Message delete and Clear history remove local transcript entries | Explain local display/history scope; keep session reset separate | P0 |
| Actions | Copy, resend, delete are 20-unit controls; chat deletion uses X | Standard icon vocabulary, larger hit areas, separate close/minimize/delete meanings | P1 |
| Attach actions | Insert selected and Attach selected describe the same draft action | Add to message (N) everywhere; success returns focus to composer | P1 |
| Row readability | Long names and metadata use fixed widths beside Details/actions | Anchor text to available space; full-value tooltips and non-overlapping metadata | P1 |
| Item data | Missing cache metadata affects rarity/slot filtering | Show Unknown metadata; distinguish missing data from no matches | P1 |
| Bank data | Last bank snapshot can appear live | Show snapshot timestamp or Never scanned; explain refresh by opening bank | P1 |
| Catalog information | Source/version text competes with primary controls | Compact data-status line; fuller source/version information on hover/details | P1 |
| Composer | Character sharing sits alongside attachments and uses Share char abbreviation | Character context: Basic/Full/Custom/Off; separate persistent setting from attachments | P1 |
| Connection | Status dot relies on tooltip; send control changes function | Text status for disconnected/connecting/ready/working/error; explicit Stop while working | P1 |
| Conversation menu | Actions are primarily discovered via right click; menu auto-dismisses | Visible menu affordance; consistent dismiss behavior and keyboard focus | P1 |
| Settings scope | Global defaults and conversation overrides require explanation | Persistent Applies to label, inherited value indication, explicit save/pending/error states | P1 |
| Dialog keyboard use | Escape behavior differs between searches and dialogs | Consistent topmost-dismiss policy with focus restoration and dirty-change protection | P1 |
| Guides | Global URL list and validation need visual assessment | Persistent global scope, link count, actionable validation, clear save result | P1 |
| Map/navigation | Pins and navigator have click/right-click behaviors | Legend, marker meaning, route name and progress; discoverable next/previous/stop controls | P2 |
| Design documentation | Design-system text still says model/reasoning are Codex-only | Update to capability-driven provider behavior and final component contracts | P1 |

## Phase 1 — Shared controls and vocabulary

Files: Theme.lua, UI-DESIGN-SYSTEM.md; representative picker adoption.

- Define reusable labeled selectors, icon-with-label buttons, checkboxes,
  search fields, count/status lines, tooltips, and dialog footers.
- Use existing native assets where verified; otherwise use consistent drawn
  icons. Icons supplement text, except familiar compact chat actions with tooltips.
- Vocabulary: map pin = location/city/zone; bag = items; scroll = quests;
  entrance/group = dungeon/raid; silhouette = character context; book = guides;
  magnifier = search; copy sheets = copy; repeat arrow = resend; trash = delete.
- Distinguish primary, secondary, selected, disabled, destructive, and error states.
  Do not use color as the only indication. Increase primary-action emphasis
  without making every control brighter.
- Preserve central typography; measure clipping before altering font sizes.
  Target at least 28-unit compact action hit areas, with matching row spacing.
- Use readable disabled reasons and full-label tooltips, including disabled
  controls through a compatible wrapper if needed.

Acceptance: the same control has the same appearance and behavior on all
screens; selected values retain field names; arrows never imply cycling.

## Phase 2 — Unify Items, Quests, and Instances

Files: Items.lua, Quests.lua, Instances.lua, shared controls in Theme.lua.

- Standard layout: title/help, source tabs, labeled search, filter area,
  result/selection summary, results, pagination, selection tools, footer.
- Replace cycling rarity, slot, and quest status controls with dropdowns.
  Retain hierarchy for city -> zone and explain what each location represents.
- Show numeric level boundaries; verify required item level is not confused
  with item level. Explain the +/-5 behavior without relying on shorthand.
- Use common selection contracts: filter/page changes preserve selection;
  source tabs retain independent selections; returning to a source restores them.
  Reconcile unavailable entries on data refresh and report removed selections.
- Select page adds current-page results. Select all results adds all matches
  across pages. Neither includes unrelated hidden entries. Clear selection
  is the only bulk removal action. Show selected only changes visibility.
- Show total results, page range, selected count, and hidden selected count.
  Reset filters preserves selection; source-specific invalid filters reset clearly.
- Standardize Add to message (N), Cancel, limits and over-limit explanations.
  Check empty state, catalog unavailable/loading, unknown metadata and errors.
- Reserve space for Details and checkboxes; add full-name/location tooltips.
  Bound metadata to the text column and inspect long names at every supported width.
- Make bank snapshot age explicit. Keep catalog provenance available without
  dominating the source tabs.
- On successful insertion, close the picker and focus the composer with the
  caret at the end. On failure, retain selection and explain the corrective action.

Acceptance: identical multi-page selection scenario behaves the same in all
three pickers; exact-boundary and over-limit cases are clear; nothing sends
until the user chooses Send. Existing virtualized/bounded row counts remain.

## Phase 3 — Chat, composer, and conversation navigation

Files: AzerMind.lua, Links.lua, Bindings.xml, Theme.lua.

- Group attachment actions separately from persistent Character context settings.
  Update tooltips to cover both owned/log and database sources.
- Always show Copy and Delete on real messages; Resend only on user messages.
  Explain why resend is disabled during unrelated pending work.
- Keep actions inside their own message bounds, even with one-line text,
  long timestamps, wrapped replies, and reused bubble frames.
- Add an undo opportunity for individual local deletion. Explain that it does
  not erase the provider's session memory or bridge transcript. Verify restore
  behavior before promising deleted messages cannot reappear.
- Distinguish Clear local history, Reset AI session, and Delete conversation.
  Whole-conversation deletion remains confirmed; avoid confirmations for every
  reversible message action.
- Add a visible conversation-menu affordance and accurate provider/settings
  access. Preserve unread indicators, new-chat focus, and keyboard bindings.
- Add concise connection/activity text and clear Connect, Send, and Stop states.
  Verify whether composer contents survive each transition and explain failures
  near the affected action instead of overwriting unrelated status.
- Keep resize behavior predictable; avoid unexpected scroll-to-bottom when
  reading older messages. Preserve scroll position for local edits/deletes,
  and offer a New messages / Jump to latest affordance when appropriate.

Acceptance: actions target the correct message after rerender, delete, chat
switch and pending reply; composer draft survives failure; keyboard is released
when hidden; attachments and automatic character sharing are distinguishable.

## Phase 4 — Settings, sharing, guides, and map tools

Files: Settings.lua, AzerMind.lua, Map.lua, design-system documentation.

- Expose AI settings for every supported provider. Show only supported model
  and reasoning choices; distinguish Automatic from unavailable metadata.
- Use Applies to: All conversation defaults / This conversation. Preserve
  unsaved fields and explain pending acknowledgements or failed saves.
- Unify settings navigation for AI, Character context, Guide references, and
  shortcut discoverability; avoid unnecessary stacked settings dialogs.
- Character sharing: show enabled state, preset/custom state, category selection,
  global scope, preview and save feedback. Disable irrelevant editing when off
  without discarding saved category choices.
- Guides: show link count/limit and global scope; validation identifies the
  offending entry and preserves other input. Saving affects future messages.
- Map: verify pin legend, quest/route/resource distinction, tooltip readability,
  route progress, destination, and missing-coordinate/map states. Add discoverable
  controls for navigation steps and stop, preserving existing shortcuts.

Acceptance: every setting communicates scope, effective value, supported
capabilities and save outcome; map actions are understandable without knowing
right-click shortcuts; existing provider and map behavior remains intact.

## Phase 5 — In-game verification and release

Source tests cannot certify appearance or live key-binding discovery.

| Dimension | Required cases |
| --- | --- |
| Screens | Chat/sidebar/menu, all three pickers, copy/details, AI settings, character context, guides, map/navigator, minimized bar |
| Size | Minimum supported window, default, expanded; 1280x720, 1920x1080, 2560x1440 where available; low/default/high client UI scale |
| Content | Empty, one entry, many pages, long names, long locations, multiline reply, links, unknown item metadata, unavailable catalog |
| Selection | Across pages and filters, source switches, selected-only, reset filters, page/all selection, limits, successful/failed insertion |
| State | Disconnected, connecting, ready, pending, error, cancelled, inherited settings, unsaved edits, pending/failed save |
| Input | Mouse, keyboard opening, new chat, Escape, Enter/Shift+Enter, tooltip navigation, focus return, combat where applicable |
| Legibility | Bright and dark game backgrounds, opaque dialogs, no clipped labels, distinguishable selected/disabled states, no color-only meaning |
| Map | Route/resource/quest markers, overlapping markers, next/previous/stop, other map, missing position |

Automated checks: Lua parsing/order, meaningful addon behavior tests for changed
selection/dropdown/message/settings contracts, existing provider and map tests,
and diff checks. Do not add tests that merely mirror every label.

Capture before/after screenshots in game for visual sign-off, including the
minimum-size/long-content cases. Verify packaged files and installed paths;
confirm key bindings on the actual client after required restart/reload.

## Delivery order and completion rule

1. Shared components and contracts (Phase 1).
2. Picker consistency and highest-impact usability corrections (Phase 2).
3. Chat actions, composer, status and navigation (Phase 3).
4. Settings and map polish (Phase 4).
5. Full visual and regression verification (Phase 5).

Each phase should be reviewable independently and update the design-system
document. Preserve unrelated ongoing changes. Finish a phase only when its
behavior tests pass and its required visual cases are observed; otherwise
record the remaining validation explicitly. No automatic publishing is planned.
