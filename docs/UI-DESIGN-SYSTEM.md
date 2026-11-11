# AzerMind interface system

The interface should feel at home in Warcraft: warm charcoal, ivory text,
gold headings, and a soft teal glow inspired by Forever's quest tint. Keep
flat surfaces dark and neutral; teal is a fading decorative wash, not a blue
panel fill. All product labels are English.

The treatment is implemented independently with native textures and gradients.
No Forever Quest Tint code, textures, or logos are bundled. Settings retain an
opaque base beneath the glow. Gradients and rim textures are created once per
frame and only resize when the frame changes size; there is no glow animation.

## Source of truth

`addon/AzerMind/Theme.lua` owns semantic colors, fonts, spacing, message roles,
surfaces, buttons, field selectors, and selected states. Load it before UI code.
New screens should reuse these components rather than copy RGB values.

| Token | Use |
| --- | --- |
| window | Opaque dialog background |
| panel | Navigation and dropdown surfaces |
| field | Resting buttons and selectors |
| selected | Active tabs and navigation |
| border | Quiet one-pixel outlines |
| gold | Headings and restrained Warcraft ornament |
| accent | Pale teal selection outlines and assistant labels |
| text | Primary ivory text |
| muted | Secondary and disabled text |
| hover | Subtle gold pointer highlight |

## Components and interaction

- Dialogs: solid background above the chat; title, content, and footer actions.
- Navigation: selected entry uses the teal border and a dark tinted surface.
- Scope tabs: active tab remains enabled and visibly selected. Never communicate
  selection by making the active tab look disabled.
- Selectors: left-aligned value, trailing arrow, neutral warm surface; click opens
  a list. Do not cycle values on click.
- Checkboxes: affirmative English labels such as "Use default settings".
- Inheritance: inherited fields are dimmed and disabled, with an explanation.
- Buttons: neutral at rest, subtle teal highlight on hover; disabled text is muted.
- Saving: show pending status until the bridge confirms a global change.
- Conversation changes: explain when the next message begins a fresh session.

Use 4/8/12/20/28-unit spacing, 26–28-unit controls, and native font templates.
Typography is centralized in `Theme.typography`: native Friz Quadrata at 18 for
titles, 15 for headings, and 13 for labels; Arial Narrow at 14 for messages,
inputs, and conversation names. Message text uses 3 units of additional line
spacing, no outline, and a restrained black shadow. No external fonts are bundled.
Keep body text left aligned. Color supplements labels; it never replaces them.
Show only working pages. AI settings are accessible for every provider. Model
choices and reasoning options follow the capabilities reported by that provider;
unsupported reasoning controls stay hidden.

## Adoption

Settings, scope tabs, dropdown rows, shared chat buttons, and message role colors
use the theme. Native minimize, checkbox, and scrollbar controls retain Blizzard's
assets. Other legacy UI can migrate incrementally when touched.

## Implemented interaction contracts

- `Theme.Selector` retains the field label and value, includes an arrow,
  and opens `Theme.ShowChoiceMenu`; opening never changes the selected value.
  The menu supports search, arrow keys, Enter, Escape, outside click, bounded
  rows, empty results and full-label tooltips.
- `Theme.Toggle` is a native checkbox with an expanded label hit area.
  `Theme.SearchField` puts the search description above the field.
- `Theme.Icon` and `Theme.IconLabel` share drawn native-texture symbols for
  locations, items, quests, instances, character context, guides and deletion.
  Text always accompanies filter and composer icons.
- `Theme.Primary` emphasizes adding selections to a message. The final Send
  action remains separate. Pickers use **Add to message (N)** consistently.
- `Theme.SourceSelection` preserves independent source selections.
  `Theme.ReconcileSelection` removes entries no longer present in a refreshed
  source. Filtering and paging never silently clear valid selections.
- **Select page** and **Select all results** add to the selection. **Clear
  selection** removes it. **Reset filters** keeps it. **Show selected only**
  changes visibility, not the selection.
- `Theme.FitDialog` keeps modal backgrounds opaque and fits dialogs within the
  current UI viewport. This is a fitting safeguard, not proof of readability
  at every UI scale; in-game validation remains required.
- `Theme.ProtectChanges` preserves unsaved settings when the parent is hidden
  and asks before explicit close discards them. Cancel explicitly discards;
  Save commits. The provider acknowledgement still owns default-save success.
- Copy/Delete remain available on every stored message; Resend appears only on
  user messages. Individual deletion has a local Undo action and retains AI
  session memory. Clearing local history and resetting the AI session are
  separate conversation-menu actions.
- Rerenders preserve the reading position when away from the bottom and offer
  **Jump to latest**. A conversation switch follows the destination transcript.
- Map navigation offers visible Previous/Next/Stop controls in addition to the
  existing drag and right-click shortcuts. The navigator tooltip explains
  marker meanings.

## Reference detail windows

Dungeon/raid details use the reference view bundled in Instances.lua: an opaque reference window with
an instance summary, separate boss navigation and loot panels, bounded row
pools, search, pagination and native item actions. Read-only details never send
a message. Copy summary explicitly opens the selectable copy dialog; opening
Details itself never highlights text or uses an EditBox as its content surface.
Missing IDs remain name-only references with an explanation. Back preserves
the originating list, and entrance-map actions uncover the map rather than
leaving a fullscreen detail dialog over it. Buttons use the template-free theme
treatment; suggested level ranges are labeled as suggestions, not requirements.


## Follow-up controls (UI 2026-11-11.2)

- Required character level uses editable numeric Min/Max, independently of item level.
- Database ownership compares item IDs with equipment, bags and cached bank snapshots.
- Source browsing is local and paginated; AI questions are separate draft actions.
- Quest map/action buttons do not share the row checkbox hit region.
- Class/race browsing masks are independent of actual-character availability status.
- Child settings return to their parent; unsaved-change protection can keep a child open.
- Reply sounds and chat keys have visible settings pages. Key conflicts are reported.
- Conversation scrollbars reserve the Undo footer only while that footer is visible.
- Installed-file verification and a visible revision distinguish source edits from live acceptance.
