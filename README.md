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

- An English (US) dictionary with more than 121,000 valid word forms.
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

The options have three pages:

- **General:** enable or pause checking, turn word coloring on or off, recognize WoW vocabulary, ignore uppercase abbreviations, show or hide the minimap button, choose 2-8 suggestions, adjust the suggestion-panel size and word color, and try a sentence.
- **Chat channels:** choose which channels to check, including Say, Yell, Whispers, Guild, Officer, Party, Raid, Instance/Battleground, public/custom channels, and Emotes. Emote checking is off by default.
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

Version **1.0.0** supports **English (US)** and standard Blizzard chat boxes.

It checks individual words, rather than grammar or sentence meaning. A correctly spelled word such as `their` is accepted even if you meant `there`.

URLs, item links, numbers, non-English script, and words longer than 28 letters are skipped. Slash commands are skipped as a whole. Additional languages and third-party chat windows are not currently supported.

## Dictionary credits

The English dictionary comes from **SCOWL**, maintained by Kevin Atkinson and contributors, through LibreOffice. Its affix data derives from Geoff Kuenning's Ispell.

The bundled word list is generated from that data by expanding valid word forms, converting entries to lowercase, excluding compound-only entries, and retaining the dictionary's restrictions on suggestions. Full credits, license notices, and disclaimers are included in [DICTIONARY-LICENSE.txt](DICTIONARY-LICENSE.txt).

See [CHANGELOG.md](CHANGELOG.md) for release notes.
