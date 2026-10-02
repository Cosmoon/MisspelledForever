# MisspelledForever Changelog

## 1.0.0
- Fixed guild/friend name normalization calling unavailable global `string_match` before local string aliases were in scope.
- Added Dutch `nlNL (Nederlands - Nederland)` and `nlBE (Nederlands - Vlaanderen)` LoadOnDemand dictionary modules.
- Generated Dutch dictionaries from OpenTaal `opentaal-hunspell` under the Revised BSD License option.
- Added `FLAG long` support to `WordDict` so two-character Hunspell affix flags work.
- Added locale aliases: `nl` maps to `nlNL`, and `vl` maps to `nlBE`.
- Added `tools/convert-opentaal.js` to regenerate the Dutch dictionary modules from OpenTaal source files.
- Split dictionaries into sibling LoadOnDemand addon modules.
- Removed dictionary Lua files from the main addon TOC so startup only loads the selected dictionary.
- Added dictionary-module reporting to `/msf status`.
- Added enUS fallback handling when a selected locale module cannot be loaded.
- Refactored addon settings into centralized defaults and compatibility helpers.
- Added AceConfig/AceConfigDialog options support with a fallback options panel.
- Replaced copied dictionary checkbox setup with table-driven dictionary settings.
- Added saved highlight color, cache limit, and per-chat-type spellchecking toggles.
- Expanded slash commands: `/msf options`, `/msf userdict`, `/msf import`, `/msf export`, `/msf reload`, `/msf status`, `/msf cache clear`, `/msf color`, `/msf enable`, and `/msf disable`.
- Added user dictionary import/export helpers.
- Added cache status and explicit cache clearing.
- Improved friend/guild matching by stripping realm suffixes and comparing normalized names.
- Added a small WoW/Forever vocabulary seed list.
- Added `MisspelledForever.toc` for the `MisspelledForever` addon folder.
- Added WoW Forever interface `16001`.
- Renamed addon-facing identifiers to `MisspelledForever`.
- Added a new port logo and `IconTexture`.
- Added initial slash commands `/misspelledforever` and `/msf`.
- Fixed modern boolean guild checks and friend API table handling.
