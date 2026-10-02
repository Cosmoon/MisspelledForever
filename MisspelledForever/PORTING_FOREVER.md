# MisspelledForever Port Notes

This addon is based on the original chat spellchecker by Nate (Nathan Pieper). Keep original credits, upstream links, and GPL obligations intact when distributing changes.

## Completed

- Added `MisspelledForever.toc` so the addon can load from a folder named `MisspelledForever`.
- Added `16001` to the TOC interface list for WoW Forever beta compatibility.
- Kept original author credit and marked this as a WoW Forever port.
- Added `Assets/MisspelledForeverLogo.png` and referenced it via `IconTexture`.
- Renamed the addon object, locale namespace, saved variables, XML frame, and config globals to `MisspelledForever`.
- Added slash commands: `/misspelledforever` and `/msf`.
- Expanded slash commands for options, user dictionary, import/export, reload, status, cache clear, highlight color, and chat type toggles.
- Centralized defaults and compatibility helpers for addon metadata, chat send, guild/friend APIs, settings, names, and cache behavior.
- Added AceConfig/AceConfigDialog integration when AceConfig is available through Ace3, with a fallback panel when it is not.
- Refactored dictionary options to be table-driven.
- Added configurable highlight color, cache limit, and per-chat-type spellchecking.
- Added user dictionary import/export helpers.
- Added cache status reporting and explicit cache clearing.
- Split dictionaries into sibling LoadOnDemand addon modules and removed dictionary files from the main TOC.
- Added Dutch `nlNL (Nederlands - Nederland)` and `nlBE (Nederlands - Vlaanderen)` dictionary modules from OpenTaal `opentaal-hunspell`.
- Added migration from the earlier `nl`/`vl` saved dictionary values to `nlNL`/`nlBE`.
- Added `FLAG long` affix support for dictionaries that use two-character Hunspell flags.
- Added OpenTaal license files to the Dutch dictionary module folders.
- Added dictionary module reporting to `/msf status`.
- Improved friend/guild matching with normalized realm-stripped names.
- Added a small WoW/Forever vocabulary seed list.
- Made `SendChatMessage` call the hook that was actually installed, instead of deriving that from `WOW_PROJECT_ID`.
- Fixed `IsInGuild() == 1` for modern boolean returns.
- Fixed friend matching in `IsFriend`, which compared a string against the `C_FriendList.GetFriendInfoByIndex` return table.

## Deferred

- The right-click suggestion menu still uses `UIDropDownMenuTemplate`. Test this in Forever; if it taints or breaks, replace it with the modern Menu API.
- The selected dictionary still requires a UI reload after changing, because upstream `WordDict:Init()` discards dictionary loader functions after initialization.
- OpenTaal compound rules, forbidden flags, and morph metadata are not fully modeled by the old Misspelled engine. Forbidden entries are filtered during generation; compound-only behavior is intentionally approximated.

## Remaining Checks

- Test load in the Forever client with Lua errors enabled.
- Verify chat edit boxes are all hooked in Forever. The timer scan likely works, but chat frame creation can be lazy.
- Verify guild roster APIs and events in Forever, especially roster update timing.
- Confirm WoW shows the PNG `IconTexture` in the AddOns list for this client. This is not a minimap button; a minimap/addon-compartment entry would need separate implementation.
- Add the full upstream GPL license text before publishing, after confirming the exact upstream GPL version.
