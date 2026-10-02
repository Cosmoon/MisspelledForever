# MisspelledForever

MisspelledForever is a WoW Forever port of the original **Misspelled** chat spell-checker addon by Nate (Nathan Pieper). Original project links and author credit are preserved in the TOC metadata and below; port-specific changes are tracked separately.

MisspelledForever watches text in the chat edit box, highlights likely misspellings, and offers right-click suggestions. It uses Hunspell-style compressed dictionaries and includes US English, UK English, French, German, Italian, Russian, Spanish, Dutch Netherlands, and Dutch Flanders dictionaries.

## Forever Port Changes

- Addon ID, saved variables, locale namespace, XML frame names, and config globals are renamed to `MisspelledForever`.
- TOC includes the WoW Forever beta interface version `16001`.
- Options use AceConfig/AceConfigDialog when available, with a built-in fallback options panel.
- Dictionaries are split into LoadOnDemand modules, so only the active dictionary is loaded at startup.
- Added Dutch dictionary modules for `nlNL (Nederlands - Nederland)` and `nlBE (Nederlands - Vlaanderen)`, generated from OpenTaal `opentaal-hunspell`.
- Dictionary options are table-driven instead of duplicated checkbox code.
- Slash commands include options, user dictionary, import/export, reload, status, cache clear, highlight color, and chat type toggles.
- Highlight color, cache limit, and enabled chat types are saved settings.
- Friend and guild member matching strips realm names and compares case-insensitively.
- A small WoW/Forever vocabulary list is injected after the selected dictionary loads.

## Commands

- `/msf options` or `/misspelledforever options`
- `/msf userdict`
- `/msf import word1 word2`
- `/msf export`
- `/msf reload`
- `/msf status`
- `/msf cache clear`
- `/msf color ff7dc6fb`
- `/msf enable guild`
- `/msf disable whisper`

## Install Layout

Keep the main addon folder and the dictionary modules next to each other in `Interface/AddOns`:

- `MisspelledForever`
- `MisspelledForever_Dict_deDE`
- `MisspelledForever_Dict_enGB`
- `MisspelledForever_Dict_enUS`
- `MisspelledForever_Dict_esES`
- `MisspelledForever_Dict_frFR`
- `MisspelledForever_Dict_itIT`
- `MisspelledForever_Dict_nlBE`
- `MisspelledForever_Dict_nlNL`
- `MisspelledForever_Dict_ruRU`

The dictionary module matching the selected language is loaded on demand. If a selected locale cannot be loaded, MisspelledForever falls back to `enUS`.

The `nlNL` and `nlBE` modules are generated from OpenTaal `opentaal-hunspell` and include `LICENSE-OpenTaal.txt` in each module folder. The port uses OpenTaal's Revised BSD License option.

## Original Project

- Original CurseForge: [https://www.curseforge.com/wow/addons/misspelled](https://www.curseforge.com/wow/addons/misspelled)
- Original repository metadata: `wow/misspelled/mainline`
- Original author: Nate (Nathan Pieper)

## Dictionary Sources

- Dutch `nlNL` / `nlBE`: [OpenTaal opentaal-hunspell](https://github.com/OpenTaal/opentaal-hunspell), Revised BSD License option.

## License

The original addon states that it is distributed for GPL-compliant projects. Keep upstream attribution intact and do not remove original author or dictionary license notices. Third-party dictionary license files must remain bundled with their dictionary modules.
