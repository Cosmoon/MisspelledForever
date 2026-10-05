# MisspelledForever

A chat spellchecker for **WoW Forever**. MisspelledForever marks possible spelling mistakes in a different color and offers corrections when you click a word.

Inspired by **Misspelled**, created by [nrpieper](https://www.curseforge.com/members/nrpieper). MisspelledForever has its own implementation, spelling engine, and interface.

## How to use it

Type your message as usual. Once you finish a word with a space or punctuation, the addon checks its spelling. Words it does not recognize appear in your chosen highlight color.

Click a colored word to see suggestions, then click the spelling you want. Only that occurrence is replaced, and its capitalization is preserved. You can also right-click a word to check it before typing a space.

You stay in control: suggestions open only when you click a word. Continuing to type, clicking elsewhere, or closing the chat box dismisses them. The addon never sends a message or applies a correction automatically.

If a word is correct but unfamiliar to the addon:

- **Learn word** adds it to your personal dictionary for future sessions.
- **Ignore for session** accepts it until you log out or reload the interface.

Item links and their formatting are preserved. The highlight colors are removed before your message is sent or saved in chat history.

## Features

- Offline dictionaries for English (US/UK), German, French, Spanish (Spain), Italian, and Dutch (NL/BE).
- Enable up to two languages together for mixed-language chat, with accented letters supported.
- Suggestions for missing letters, extra letters, swapped letters, and mistyped letters.
- A wider search for longer words when the first and last letters match.
- Built-in WoW vocabulary, including common spells, locations, classes, and chat shorthand.
- Recognition of your character, party members, raid members, and target names for the current session.
- A personal dictionary for names, guild terms, and your own shorthand.
- Options for chat channels, highlight color, suggestion count, and suggestion-panel size.
- A draggable minimap button that you can hide.
- A bundled dictionary with no separate dictionary addons or Lua libraries required.

## Settings

Open the options with **`/mf`** or **`/misspelledforever`**, click the minimap button, or select **MisspelledForever** in the game's AddOns settings.

The options have four pages:

- **General:** enable or pause checking, turn word coloring on or off, recognize WoW vocabulary, ignore uppercase abbreviations, show or hide the minimap button, choose 2-8 suggestions, adjust the suggestion-panel size and word color, and try a sentence.
- **Chat channels:** choose which channels to check, including Say, Yell, Whispers, Guild, Officer, Party, Raid, Instance/Battleground, public/custom channels, and Emotes. Emote checking is off by default.
- **Languages:** enable one or two spelling dictionaries. At least one must stay enabled; turn one off before selecting a replacement when two are active. Dutch (NL) and (BE) share OpenTaal data, including Belgian Dutch vocabulary.
- **Personal words:** add or remove words, one per line, with up to 800 entries. Click **Save word list** to save your edits. You can also clear session ignores here.

General and channel settings save immediately. **Reset options** restores the default settings and keeps your personal dictionary.

## Minimap button

- **Left-click:** open settings.
- **Right-click:** enable or pause spelling checks.
- **Drag:** move the button around the minimap.

Its position and visibility are saved. You can hide it in General settings or with `/mf minimap`. Settings remain available through `/mf` and the game's AddOns settings.

## Commands

| Command | Action |
| --- | --- |
| `/mf` | Open settings |
| `/misspelledforever` | Open settings |
| `/mf on` | Enable spelling checks |
| `/mf off` | Pause spelling checks |
| `/mf minimap` | Show or hide the minimap button |
| `/mf add yourword` | Add a word to your personal dictionary |
| `/mf help` | Show command help |

## Language and compatibility

Version **1.1.0** supports **English (US and UK), German, French, Spanish (Spain), Italian, and Dutch (NL and BE)** in standard Blizzard chat boxes. Open `/mf`, then **Languages**, to select one or two dictionaries. Existing settings keep English (US) enabled until you change them.

Words are accepted by any enabled dictionary, and corrections come from the combined dictionaries. A maximum of two active languages limits memory use and suggestion time. Dutch (NL) and (BE) use the same dictionary without duplicate entries.

It checks individual words, rather than grammar or sentence meaning. A correctly spelled word such as `their` is accepted even if you meant `there`.

URLs, item links, numbers, non-Latin scripts, and words longer than 28 characters are skipped. Slash commands are skipped as a whole. Accents, Unicode capitalization, and composed/decomposed accents are supported; chat cursor positions continue to use the game's byte offsets.

The bundled lists contain standalone words and finite inflections. They do not synthesize arbitrary compound words, so some valid German or Dutch compounds may need to be added to your personal dictionary. Capitalization rules and grammar are not enforced. Third-party chat windows are not currently supported.

## Dictionary credits

The English dictionary comes from **SCOWL**, maintained by Kevin Atkinson and contributors, through LibreOffice. Its affix data derives from Geoff Kuenning's Ispell.

The bundled word list is generated from that data by expanding valid word forms, converting entries to lowercase, excluding compound-only entries, and retaining the dictionary's restrictions on suggestions. Full credits, license notices, and disclaimers are included in [DICTIONARY-LICENSE.txt](DICTIONARY-LICENSE.txt).

Additional dictionaries come from the LibreOffice dictionary collection: British English, igerman98/frami (German), Grammalecte (French), RLA-ES (Spanish), LibreItalia (Italian), and OpenTaal (Dutch). The upstream OpenTaal dictionary explicitly supports both `nl-NL` and `nl-BE`.

See [Data/Licenses](Data/Licenses) for each dictionary's original notices and license terms. The added word lists are modified, lowercase, standalone-form expansions of the [LibreOffice dictionaries](https://github.com/LibreOffice/dictionaries/tree/32b006a2c22a4ac7e8ed3f03346f7b3d85a970a4); their original data licenses still apply.

See [CHANGELOG.md](CHANGELOG.md) for release notes.
