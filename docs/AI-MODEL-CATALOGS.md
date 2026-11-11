# AI model dropdowns

The bridge supplies model choices to Settings > AI Config. Users normally
choose a named model, then one of its reported reasoning levels. Automatic
uses the CLI configuration. Advanced: custom model ID remains the last option.

## Catalog sources

| Agent | Source | Fallback |
| --- | --- | --- |
| Codex | Existing account-local models_cache.json, including supported reasoning levels | Automatic/custom when no local catalog is available; no guessed account roster |
| Claude | Configured model metadata and documented compatibility choices | Opus/Sonnet/Haiku aliases and researched pinned models; account access unverified |
| Grok | Read-only --help capability probe and models listing | Documented compatibility choices; effort stays unavailable unless the installed CLI advertises --effort |
| Antigravity | Read-only --help probe and models listing | Documented Gemini variants; a variant is not combined with an invented effort override |
| Hermes | Configured provider model metadata | Documented provider-resolved aliases; no assumption about authenticated routes or reasoning support |

Compatibility choices are explicitly labeled and do not guarantee model
access. Unknown reasoning capabilities offer Automatic only. For example,
the current Opus alias cannot safely imply the reasoning capabilities of every
backend version. A pinned known model or explicit provider metadata supplies
those choices. Empty known effort lists mean fixed/no adjustable reasoning;
omitted/unknown effort metadata means unknown, not support for every effort.

All providers merge `agents.<id>.models` with the catalog. Explicit configured
entries take precedence and the current configured model remains reachable.
For a custom deployment, an optional declaration is:

```json
{
  "model": "team-deployment",
  "name": "Team deployment",
  "efforts": ["low", "high"]
}
```

Place that object in the provider's existing `models` array. Model-specific
effort IDs reported by a CLI (such as a Grok route's `deep`) are retained as
their actual IDs, not translated silently into a generic level.

## Refresh and persistence

- Normal bridge startup probes provider help/listing commands in the background.
  One-shot/injection runs do not probe CLIs.
- **Refresh models** requests a new catalog through the bridge. It does not
  start inference, change provider defaults or discard unsaved settings.
- Probes use argument arrays without a shell, hidden Windows processes, a
  3.5-second timeout per invocation and bounded output. There are no installs,
  sign-ins, interactive pickers or model-list requests from the addon itself.
- Concurrent refreshes share one operation, with a 10-second minimum interval.
  The bounded metadata cache is `bridge/model-catalog-cache.json`, ignored by
  git. Last-good discovery may be reused for up to seven days and is marked
  cached/stale; a failed refresh does not erase the list.
- Only sanitized model IDs, names and effort metadata reach WoW. Credentials,
  CLI output, endpoint settings and arbitrary configuration are not forwarded.
- Lists use a searchable, scrollable menu with at most nine row frames. Model
  changes clear the previous effort, and known invalid combinations cannot be
  saved. Choosing a new provider restores that provider's own overrides/defaults.
- Global defaults still require bridge acknowledgement. Conversation changes
  apply to the next message with a fresh session; an in-flight reply is not switched.

Restart the bridge after updating its JavaScript files, rebuild/copy the addon,
and `/reload` before testing the new controls. Missing CLIs and unverified
fallback lists are reported in the catalog status/Refresh tooltip.

## Research and validation

Compatibility entries were researched on 2026-11-11:

- [Claude model configuration](https://code.claude.com/docs/en/model-config)
- [Grok CLI model discovery and effort flag](https://docs.x.ai/build/cli/reference)
- [Grok model-specific reasoning metadata](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-pager/docs/user-guide/26-config-reference.md)
- [Antigravity model slugs](https://antigravity.google/docs/cli/headless/)
- [Antigravity effort capabilities](https://antigravity.google/docs/cli/commands/effort)
- [Hermes provider catalogs and aliases](https://hermes-agent.nousresearch.com/docs/user-guide/configuring-models)

Local read-only verification found eight Codex models, Claude Code 2.1.161
with --effort support, and no resolved Grok/Antigravity/Hermes executable on
this machine. Tests simulate live catalogs and failures for those adapters;
their authenticated account discovery is not claimed as live-verified.
