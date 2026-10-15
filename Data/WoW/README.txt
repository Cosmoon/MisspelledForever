WoW Multilingual Spellcheck - Forever vocabulary

Imported from the user-supplied WoW_Multilingual_Dictionaries/Forever package.
All 42 category files retain their original entries and comments; only the
namespace was adapted to preserve separate locale packs in MisspelledForever.

WoW MULTILINGUAL SPELLCHECK - 2 games x 6 language sets

Folders: Forever/ and Retail/, with enUS, deDE, frFR, esES, itIT, nlNL.
Every set includes separate Locations, Bosses, Spells, Items, Professions, Jargon, Classes Lua files.
Each Lua file adds terms to ns.SpellcheckWords[category].

IMPORTANT LIMITATIONS:
- Core English dictionaries are curated starter sets, not a complete enumeration of every WoW item, NPC, spell or area.
- German, French, Spanish and Italian add a LIMITED curated vocabulary of localized names. Most English terms remain shared by design; NOT every name in a language folder is a translation.
- Dutch (nlBE) is community-language vocabulary, NOT an official WoW localization. Many localized names should remain English.
- Spellchecking chat should support multiword phrases using longest-phrase match, and use UTF-8-aware comparison for upper/lowercase accented letters. Lua string.lower is ASCII-oriented.
- Non-ASCII items are also included in lowercase spelling for faster lookup; special case mapping should still be handled by the checker.
- Abbreviations are whitelisted, not suggested as corrections automatically.
- A real full item/spell dictionary should be exported from current Blizzard client DB2 files or a locale-specific game database by ID and version.
- TOC Interface versions are placeholders and MUST be adjusted to the actual client build, particularly WoW Forever.

References: Warcraft Wiki Localization info and Localizing an addon; Wowhead Classic localized databases.
