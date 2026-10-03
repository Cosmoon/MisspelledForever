# Changelog

## 1.0.0 - 2026-10-03

First release of the independently rebuilt MisspelledForever for WoW Forever.
Retains the addon name and logo, with a new spelling engine and interface.

### Spelling and suggestions

- Bundled English (US) dictionary with more than 121,000 valid word forms.
- Recognizes missing letters, extra letters, substitutions, and adjacent swaps.
- For typed words of 4-10 letters, allows up to three edits; for 11-28 letters,
  allows up to four. Matches beyond two edits require matching first and last
  letters and rank below closer matches. Words of 2-3 letters allow one edit.
- Ranks suggestions using common-word hints, keyboard neighbors, WoW terms,
  personal words, and familiar spelling mistakes.
- Includes WoW vocabulary and chat shorthand, plus session recognition of
  player, party, raid, and target names.
- Personal dictionary with permanent learning and temporary session ignores.
- Suggestions are calculated in short batches and cached to keep chat responsive.

### Chat experience

- Completed unrecognized words appear in a different color in the chat box.
- Click a colored word to open its suggestions; no automatic popup while typing.
- Choose a correction to replace only that occurrence and preserve capitalization.
- Suggestions close when typing, clicking elsewhere, or closing the chat box.
- Preserves normal drag selection and original item-link formatting.
- Removes display-only colors before sending messages or saving chat history.
- Prevents repeated color resets and waits for the native cursor update before
  resolving clicks on words.

### Options and minimap

- General, Chat channels, and Personal words settings pages.
- Controls for enabling checks, word coloring, WoW vocabulary, uppercase words,
  checked channels, suggestion count, suggestion-panel size, and highlight color.
- Personal word-list editor and a sentence-check field in the options.
- Draggable minimap button with saved position and an option to hide it.
- Left-click the minimap button for settings; right-click to enable or pause checks.
- Settings remain available through `/mf`, `/misspelledforever`, and the game's
  AddOns settings when the minimap button is hidden.
- No separate dictionary addons or external Lua libraries required.

### Current scope

- English (US) spelling and standard Blizzard chat boxes.
- Checks individual words, without grammar or sentence-context analysis.
- Includes dictionary attribution, reproducible build inputs, and automated
  spelling, settings, chat-interaction, and color-cleanup regression checks.
