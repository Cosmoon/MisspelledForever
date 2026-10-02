--[[--------------------------------------------------------------------------
  Developed by Nathan Pieper - nrpieper (@) gmail (dot) com
  MisspelledForever is an interactive chat text spell checker for World of Warcraft

  This code freely distributed for your use in any GPL compliant project.
  Portions of this code are covered by the Gnu Public License (GPL)
  Dictionaries use the OpenOffice/HunSpell/ASpell dictionary format
  (http://wiki.services.openoffice.org/wiki/Dictionaries)
  Phonetic cache information created via the NetSpell dictionary util.
  References & Credits:
  Paul Welter & NetSpell: http://www.loresoft.com/projects/netspell
  Metaphone Algorithm http://aspell.net/metaphone/
  Edit Distance Algorithm http://en.wikipedia.org/wiki/Levenshtein_distance

--------------------------------------------------------------------------]]--


--[[
Challenges:


Issue #1
(http://www.wowwiki.com/ItemLink)
Color tags can be destroyed or mangled as you perform edit near the start
and end of the color tag.

If you press delete with the cursor positioned, just before, a color tag,
the start of the tag (|cffffffff) and the next character are removed.  The
closing color tag (|r) is left at the end.

If you press backspace with the cursor positioned just past the (|r) end
of a color tag, the (|r) is removed along with the character just before it.

If you press delete with the cursor positioned, just before the last char,
in a color tagged string, the character and the closing (|r) are both removed.

If you press backspace with the cursor positioned, just after the first char,
in a color tagged string, the first char and the beginning color tag are both removed.

In the case of colored item links, Wow just deletes the entire item, if you
hit a delete or backspace.

Solution:
First parse the line to flag any valid item links or textures so they don't get
destroyed by the next step.
Then if there are any remaining start or end color tag, remove them.

Issue #2
The Chat Edit box's edit cursor position is relative to characters that don't display in the
chat edit text, i.e. item link tags, color tags, and texture tags.
When we add, or remove, a color tag, to highlight a misspelled word,  we should adjust the
cursor position so it acts natural.
Note: An OnCursorChanged event doesn't exist or doesn't fire for the ChatEditBox.

Solution:
Methods that insert or delete text from the ChatEditBox need to properly adjust the cursor
position as needed when, visible or hidden, characters are inserted or deleted to the left of the cursor.

Two techniques could be used.
#1: Track the number of, printable and non-printable characters inserted or deleted
    to the left of the cursor, and adjust the cursor position to compensate.

#2: Insert a tracking char byte (example: \1), at the cursor position.  After making
	inserts and deletes, find the tracking char byte, remove it and reposition the cursor
    at its location.

I have implemented technique #1.

Issue #3 WIM Integration
Wim allows multiple chat windows at once.  So we need to track WordLocations per editbox.
Wim breaks long chat messages into multiple messages.
Wim has a EditBox right click handler to insert emoticons and previous chat messages.
WIM sends chat messages using ChatThrottleLib:SendChatMessage.  This can hot SendChatMessage before MisspelledForever and bypasses the step that cleans the highlighting.
(10/10/2009) Updated hooks, from WIM, will be provided via WIM.RegisterPreSendFilterText(func()), to remove the need to manually hook ChatThrottleLib

User Dictionary Editor Added
(12/6/2009) - Used AceGUI to add the ability to remove words from the user dictionary.

(1/12/2010) - Added enGB UK English dictionary.

(5/12/2010) - Added support for PTR Patch 3.5.  Multiple ChatEditBoxes get created.  Hook into the activate routine.

(5/23/2010) - Fixed enGB dictionary load issue.

(6/24/2010) - Added itIT Italian dictionary

(7/22/2010) - The Addon Gryphonheart Items (GHI) begins it's item color tags with a (|C) capitol C character.  I added that possibility to the chat text parsing.

(9/14/2010) - Client 4 has some issues with trying to set the owner of the popmenu items.  Looks like it's not needed.

(9/7/2019) - Wow Classic: When starting you can't have friends and the global function: GetNumFriends() is nil.  Detect and skip to eliminate the error.

(4/30/2025) - Changes added to RemoveHighlighting to parse new Item Quality # colors and Global Colors UI escape sequences.
(12/18/2025) - Wow Retail 12.2.7 changes added to hook chat frames.
--]]--

local _G = _G
local ADDON_NAME = ...
ADDON_NAME = (ADDON_NAME and #ADDON_NAME > 0) and ADDON_NAME or "MisspelledForever"

MisspelledForever = LibStub("AceAddon-3.0"):NewAddon("MisspelledForever", "AceEvent-3.0", "AceHook-3.0")

local MisspelledForever = _G.MisspelledForever

local Compat = {}

function Compat.GetAddonMetadata(addonName, key)
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		local ok, value = pcall(C_AddOns.GetAddOnMetadata, addonName, key)
		if ok then return value end
	elseif GetAddOnMetadata then
		return GetAddOnMetadata(addonName, key)
	end
end

function Compat.RequestGuildRoster()
	if C_GuildInfo and C_GuildInfo.GuildRoster then
		C_GuildInfo.GuildRoster()
	elseif GuildRoster then
		GuildRoster()
	end
end

function Compat.GetNumGuildMembers(includeOffline)
	if GetNumGuildMembers then
		return GetNumGuildMembers(includeOffline) or 0
	end
	return 0
end

function Compat.GetGuildRosterName(index)
	if GetGuildRosterInfo then
		return GetGuildRosterInfo(index)
	end
end

function Compat.GetNumFriends()
	if C_FriendList and C_FriendList.GetNumFriends then
		return C_FriendList.GetNumFriends() or 0
	elseif GetNumFriends then
		return GetNumFriends() or 0
	end
	return 0
end

function Compat.GetFriendName(index)
	if C_FriendList and C_FriendList.GetFriendInfoByIndex then
		local info = C_FriendList.GetFriendInfoByIndex(index)
		if type(info) == "table" then
			return info.name
		end
		return info
	elseif GetFriendInfo then
		return GetFriendInfo(index)
	end
end

function Compat.NormalizeName(name)
	if type(name) == "table" then name = name.name end
	if name == nil then return nil end
	name = tostring(name)
	if Ambiguate then
		name = Ambiguate(name, "none")
	end
	name = string.match(name, "^([^%-]+)") or name
	name = string.gsub(name, "%s+", "")
	if strlower then
		name = strlower(name)
	else
		name = string.lower(name)
	end
	return name
end

MisspelledForever.Compat = Compat
MisspelledForever.Version = Compat.GetAddonMetadata(ADDON_NAME, "Version") or "dev"

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("MisspelledForever", true)

local table_insert = table.insert
local string_byte = string.byte
local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_len = string.len
local string_lower = string.lower
local string_match = string.match
local string_rep = string.rep
local string_sub = string.sub
local string_upper = string.upper
local tostring = tostring
local tonumber = tonumber
local pairs = pairs
local ipairs = ipairs

local DEFAULT_HIGHLIGHT_COLOR = "ff7dc6fb"
local DEFAULT_CACHE_MAX = 7000
local SPELLED_WRONG_HIGHLIGHT_HEX_COLOR_CODE = DEFAULT_HIGHLIGHT_COLOR
local SPELLED_WRONG_HIGHLIGHT = "|c" .. SPELLED_WRONG_HIGHLIGHT_HEX_COLOR_CODE

local DICTIONARIES = {
	{ locale = "deDE", label = "deDE" },
	{ locale = "enGB", label = "enGB" },
	{ locale = "enUS", label = "enUS" },
	{ locale = "esES", label = "esES" },
	{ locale = "frFR", label = "frFR" },
	{ locale = "nlNL", label = "nlNL" },
	{ locale = "ruRU", label = "ruRU" },
	{ locale = "itIT", label = "itIT" },
	{ locale = "nlBE", label = "nlBE" },
}

local CHAT_TYPES = {
	{ key = "SAY", label = "Say" },
	{ key = "YELL", label = "Yell" },
	{ key = "EMOTE", label = "Emote" },
	{ key = "GUILD", label = "Guild" },
	{ key = "OFFICER", label = "Officer" },
	{ key = "PARTY", label = "Party" },
	{ key = "RAID", label = "Raid" },
	{ key = "INSTANCE_CHAT", label = "Instance" },
	{ key = "WHISPER", label = "Whisper" },
	{ key = "BN_WHISPER", label = "Battle.net Whisper" },
	{ key = "CHANNEL", label = "Channel" },
}

local DEFAULT_CHAT_TYPES = {}
for _, chatType in ipairs(CHAT_TYPES) do
	DEFAULT_CHAT_TYPES[chatType.key] = true
end

local FOREVER_WORDS = {
	-- Classes, races, and common WoW terms.
	"Deathknight", "Deathlord", "Demonhunter", "Draenei", "Dracthyr", "Evoker",
	"Nightborne", "Pandaren", "Voidelf", "Worgen", "Battleground", "Warband",
	"Transmog", "Transmogrification", "Cooldown", "Proc", "Respec", "Threat",
	"Taunt", "Interrupt", "Cleanse", "Dispel", "HoT", "DoT", "AoE", "CC",

	-- Forever / vanilla-flavoured places and dungeon names.
	"Azeroth", "Kalimdor", "Lordaeron", "Stormwind", "Ironforge", "Darnassus",
	"Orgrimmar", "Thunderbluff", "Undercity", "Teldrassil", "Dunmorogh",
	"Elwynn", "Westfall", "Redridge", "Duskwood", "Lochmodan", "Darkshore",
	"Ashenvale", "Stonetalon", "Desolace", "Tanaris", "Feralas", "Felwood",
	"Winterspring", "Silithus", "Blackfathom", "Deadmines", "Stockade",
	"Gnomeregan", "Razorfen", "Uldaman", "Zulfarak", "Maraudon",
	"Scholomance", "Stratholme", "Diremaul", "Blackrock", "Molten Core",
	"Onyxia", "Nefarian", "Ragnaros", "Cthun", "Kelthuzad",
}

local WordCache = {}           --Stores a cache of every word checked, along with the suggestions for words checked
local WordCacheCount = 0       --Counter used to track when we should clean the WordCache table to save memory
local WordCacheCountMax = DEFAULT_CACHE_MAX --Number of entries that can live in the WordCache before we clean the cache
local WordLocations = {}       --Lookup table used by multiple functions to determine where each work starts and ends
							   --There will be a sub-table for each EditBox:GetName() so we can store multiple sets of info at once.
local SkipOnTextChanged = false -- use to avoid OnTextChanged event firing after spell checking highlights chat text.
local RightClickedWord = nil   --The current word under the CursorPosition that was right-clicked
local RightClickedWordStartPos --Where that word starts
local RightClickedWordEndPos   --and where that word ends
local RightClickedEditBox      --and what EditBox was right clicked
local OldLineLength            --Tracks the previous length of the ChatEditBox.text
local GuildRosterCalled = false
local MaxColorCodes = 12       --The max amount of color codes we will add to the editbox text.
local FriendNameCache = {}
local GuildNameCache = {}

local MisspelledForever_Saved_CTL_SendChatMessage
local MisspelledForever_CTL_hookedversion=0

local function CountKeys(tbl)
	local count = 0
	if tbl then
		for _ in pairs(tbl) do
			count = count + 1
		end
	end
	return count
end

local function NormalizeHexColor(hex)
	hex = tostring(hex or "")
	hex = string_gsub(hex, "^#", "")
	hex = string_gsub(hex, "^|c", "")
	hex = string_gsub(hex, "[^%x]", "")
	if #hex == 6 then
		hex = "ff" .. hex
	end
	if #hex ~= 8 then
		hex = DEFAULT_HIGHLIGHT_COLOR
	end
	return string_lower(hex)
end

local function HexToRGBA(hex)
	hex = NormalizeHexColor(hex)
	local a = (tonumber(string_sub(hex, 1, 2), 16) or 255) / 255
	local r = (tonumber(string_sub(hex, 3, 4), 16) or 255) / 255
	local g = (tonumber(string_sub(hex, 5, 6), 16) or 255) / 255
	local b = (tonumber(string_sub(hex, 7, 8), 16) or 255) / 255
	return r, g, b, a
end

local function RGBAtoHex(r, g, b, a)
	local alpha = a or 1
	return string_format(
		"%02x%02x%02x%02x",
		math.floor(alpha * 255 + 0.5),
		math.floor(r * 255 + 0.5),
		math.floor(g * 255 + 0.5),
		math.floor(b * 255 + 0.5)
	)
end

local function EnsureDB()
	if MisspelledForever_DB == nil then
		MisspelledForever_DB = {}
	end

	local db = MisspelledForever_DB
	db.UserDict = db.UserDict or {}
	db.CustomWords = db.CustomWords or {}
	db.LoadDictionary = db.LoadDictionary or "enUS"
	if db.LoadDictionary == "nl" then db.LoadDictionary = "nlNL" end
	if db.LoadDictionary == "vl" then db.LoadDictionary = "nlBE" end
	if db.AutoSelectDictionary == nil then db.AutoSelectDictionary = true end
	db.HighlightColor = NormalizeHexColor(db.HighlightColor or DEFAULT_HIGHLIGHT_COLOR)
	db.CacheMax = tonumber(db.CacheMax) or DEFAULT_CACHE_MAX
	db.ChatTypes = db.ChatTypes or {}

	for chatType, enabled in pairs(DEFAULT_CHAT_TYPES) do
		if db.ChatTypes[chatType] == nil then
			db.ChatTypes[chatType] = enabled
		end
	end

	return db
end

function MisspelledForever:SetHighlightColor(hex)
	local db = EnsureDB()
	db.HighlightColor = NormalizeHexColor(hex)
	SPELLED_WRONG_HIGHLIGHT_HEX_COLOR_CODE = db.HighlightColor
	SPELLED_WRONG_HIGHLIGHT = "|c" .. SPELLED_WRONG_HIGHLIGHT_HEX_COLOR_CODE
	self:ClearWordCache()
end

function MisspelledForever:ClearWordCache()
	WordCache = {}
	WordCacheCount = 0
end

function MisspelledForever:SetCacheMax(value)
	local db = EnsureDB()
	db.CacheMax = tonumber(value) or DEFAULT_CACHE_MAX
	if db.CacheMax < 100 then db.CacheMax = 100 end
	WordCacheCountMax = db.CacheMax
	if WordCacheCount > WordCacheCountMax then
		self:ClearWordCache()
	end
end

function MisspelledForever:GetSelectedDictionary()
	local db = EnsureDB()
	if db.AutoSelectDictionary then
		return "Auto"
	end
	return db.LoadDictionary or "enUS"
end

function MisspelledForever:GetEditBoxChatType(editbox)
	local chatType
	if editbox and editbox.GetAttribute then
		chatType = editbox:GetAttribute("chatType")
	end
	chatType = chatType or (editbox and editbox.chatType) or "SAY"
	return string_upper(tostring(chatType))
end

function MisspelledForever:IsChatTypeEnabled(chatType)
	local db = EnsureDB()
	chatType = string_upper(tostring(chatType or "SAY"))
	if db.ChatTypes[chatType] == nil then
		db.ChatTypes[chatType] = true
	end
	return db.ChatTypes[chatType] ~= false
end

function MisspelledForever:SetChatTypeEnabled(chatType, enabled)
	local db = EnsureDB()
	chatType = string_upper(tostring(chatType or ""))
	if chatType == "" then return false end
	db.ChatTypes[chatType] = enabled and true or false
	self:ClearWordCache()
	return true
end

function MisspelledForever:NormalizeName(name)
	return Compat.NormalizeName(name)
end

function MisspelledForever:AddWordToDictionary(word, saved)
	if word == nil then return false end
	word = tostring(word)
	if #word == 0 then return false end

	local pcode = ""
	if WordDict.soundslike == WordDict.Const.SoundslikeAlgorithms.PHONETIC then
		pcode = WordDict:PhoneticCode(word)
	elseif WordDict.soundslike == WordDict.Const.SoundslikeAlgorithms.GENERIC then
		pcode = WordDict:GenericSoundsLike(word)
	end

	WordDict.baseWords[word] = "/" .. pcode
	if saved then
		local db = EnsureDB()
		db.UserDict[word] = "/" .. pcode
	end
	return true
end

function MisspelledForever:LoadForeverWords()
	local db = EnsureDB()
	for _, word in ipairs(FOREVER_WORDS) do
		if WordDict.baseWords[word] == nil then
			self:AddWordToDictionary(word, false)
		end
	end
	for word in pairs(db.CustomWords) do
		if WordDict.baseWords[word] == nil then
			self:AddWordToDictionary(word, false)
		end
	end
end

--Output debug messages to the DevTool addon (https://github.com/brittyazel/DevTool)
function MisspelledForever:AddToInspector(data, strName)
	if DevTool and self.DEBUG then
		local valType = type(data)

		if valType == "string" then
			-- from: https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Dump.lua
			-- %q  "quotes" the string and escapes any special characters within it (like double quotes, newlines, etc.)
			-- replacing | with || outputs UI escaped sequence strings displaying all color and link details
			data = string_gsub(string_format("%q", data), "[|]", "||")
			DevTool:AddData(data, "MisspelledForever: " .. strName)
		else
			DevTool:AddData(data, "MisspelledForever: " .. strName)
		end
	end
end

function MisspelledForever:GetTextWidth(editbox, text)
	if text == nil or text == "" then
		return 0
	end

	if self.MeasureFrame == nil then
		self.MeasureFrame = CreateFrame("Frame", nil, UIParent)
		self.MeasureFrame:Hide()
		self.MeasureText = self.MeasureFrame:CreateFontString(nil, "OVERLAY")
	end

	if editbox and editbox.GetFontObject and editbox:GetFontObject() then
		self.MeasureText:SetFontObject(editbox:GetFontObject())
	elseif editbox and editbox.GetFont then
		local fontFile, fontSize, fontFlags = editbox:GetFont()
		if fontFile then
			self.MeasureText:SetFont(fontFile, fontSize, fontFlags)
		end
	end

	self.MeasureText:SetText(text)
	local width = self.MeasureText:GetStringWidth() or 0
	self.MeasureText:SetText("")
	return width
end

function MisspelledForever:GetSuggestionMenuXOffset(editbox, cursorPos, wordEndPos)
	if cursorPos == nil or wordEndPos == nil or cursorPos >= wordEndPos then
		return 0
	end

	local text = editbox and editbox:GetText() or ""
	local remainingWord = string_sub(text, cursorPos + 1, wordEndPos)
	return self:GetTextWidth(editbox, remainingWord) + 4
end

function MisspelledForever:OnInitialize()
    --Enable to output debug messages created with calls to: AddToInspector(data, strName), to the addon: DevTool
	--self.DEBUG = true

	local db = EnsureDB()
	self:SetHighlightColor(db.HighlightColor)
	self:SetCacheMax(db.CacheMax)

	local dict = self:GetSelectedDictionary()

	--Load the Dictionary
	local dictLoaded
	if dict == "Auto" then
		dictLoaded = WordDict:Init()
	else
		dictLoaded = WordDict:Init(dict)
	end

	local dictModule = WordDict.loadedDictionaryAddon or "embedded"
	MisspelledForever:print("MisspelledForever: " .. L["Dictionary Loaded"] .." - " .. dictLoaded .. " (" .. dictModule .. ")")

	--Load user dict
	MisspelledForever:LoadUserDict()
	MisspelledForever:print("MisspelledForever: " .. L["User Dictionary Loaded"])
	MisspelledForever:LoadForeverWords()

	-- Build Interface Options window
	self:CreateInterfaceOptions()

	--Watch for other chat addons: Wim, to load and then integrate.
	MisspelledForever:RegisterEvent("ADDON_LOADED")

	--Guild members and Friends are valid words.
	--Wait for the GUILD_ROSTER_UPDATE event to load
	--the guild members & friends into the dictionary as valid words.

	--Register the GUILD_ROSTER_UPDATE event, so we know when we can load the
	--Guild member names into the database
	MisspelledForever:RegisterEvent("GUILD_ROSTER_UPDATE")


	--GuildRoster can only be called every so often.
	--If another addon triggered it first, we might miss notification.
	--Moved to OnTextChanged
	--GuildRoster()

	--Patch 3.5 has multiple ChatEditBoxes.  We need to hook in differently.
	--Updated for WoW 11.2.7: ChatEdit_ActivateChat exists but is never called.
	--Force the new timer-based approach.

	-- Use timer-based approach for 11.2.7+
	local self = MisspelledForever
	C_Timer.After(0.1, function()
		local n = _G.NUM_CHAT_WINDOWS or 10
		for i = 1, n do
			local editbox = _G["ChatFrame" .. i .. "EditBox"]
			if editbox then
				local hooked = self:IsHooked(editbox, "OnTextChanged")
				if not hooked then
					self:WireUpEditBox(editbox)
				end
			end
		end
	end)

	if ChatEdit_ActivateChat ~= nil then
		MisspelledForever:SecureHook("ChatEdit_ActivateChat")
	elseif ChatFrameEditBox ~= nil then
		MisspelledForever:WireUpEditBox(ChatFrameEditBox)
	end

	-- hooks for removing any misspelled word highlighting in the text before the chat message is sent
	-- The Wow client will disconnect if you attempt to send a color tags in a chat message.
	if C_ChatInfo and C_ChatInfo.SendChatMessage then
		MisspelledForever:RawHook(C_ChatInfo, "SendChatMessage", MisspelledForever.SendChatMessage, true)
	else
		MisspelledForever:RawHook("SendChatMessage", MisspelledForever.SendChatMessage, true) -- For non-retail game clients
	end
end


function MisspelledForever:WireUpEditBox(editbox)
	MisspelledForever:SecureHookScript(editbox, "OnEscapePressed", MisspelledForever.EditBox_OnEscapePressed)
	MisspelledForever:SecureHookScript(editbox, "OnEnterPressed", MisspelledForever.EditBox_OnEnterPressed)
	MisspelledForever:SecureHookScript(editbox, "OnTextChanged", MisspelledForever.EditBox_OnTextChanged)
	MisspelledForever:HookScript(editbox, "OnMouseUp", MisspelledForever.EditBox_OnMouseUp)  -- Used to hook mouse right-clicks to show suggestions frame
end

function MisspelledForever:GUILD_ROSTER_UPDATE()
	MisspelledForever:LoadGuildAndFriendRoster()
end

function MisspelledForever:ADDON_LOADED(event, addonName)
	if event == "ADDON_LOADED" and addonName == "WIM" then
		WIM.RegisterWidgetTrigger("msg_box", "whisper,chat,w2w", "OnEscapePressed", MisspelledForever.EditBox_OnEscapePressed)
		WIM.RegisterWidgetTrigger("msg_box", "whisper,chat,w2w", "OnEnterPressed", MisspelledForever.EditBox_OnEnterPressed)
		WIM.RegisterWidgetTrigger("msg_box", "whisper,chat,w2w", "OnTextChanged", MisspelledForever.EditBox_OnTextChanged)
		--WIM.RegisterWidgetTrigger("msg_box", "whisper,chat,w2w", "OnMouseUp", MisspelledForever.EditBox_OnMouseUp)


		--Before a chat message is sent, remove any highlighting that MisspelledForever might have added.
		--The Wow client will disconnect if you attempt to send a colored chat message.

		--If available use the WIM API: Wim.RegisterPreSendFilterText

		--WIM sends its chat messages via the API ChatThrottleLib,
		--ChatThrottleLib hooks the default SendChatMessage api, many times, before MisspelledForever can.
		--ChatThrottleLib is used in many addons, that potentially load before MisspelledForever.
		--So we have to hook ChatThrottleLib just to be safe.


		if(WIM.RegisterPreSendFilterText) then -- avoid error if WIM not up to date.
			WIM.RegisterPreSendFilterText(function(text)
											return MisspelledForever:RemoveHighlighting(text)
										  end)
		else
			if(ChatThrottleLib and MisspelledForever_CTL_hookedversion < ChatThrottleLib.version) then
				MisspelledForever_Saved_CTL_SendChatMessage=ChatThrottleLib.SendChatMessage

				function ChatThrottleLib:SendChatMessage(prio, prefix, text, ...)
					text = MisspelledForever:RemoveHighlighting(text)
					--print("MisspelledForever Hooked ChatThrottleLib_SendChatMessaged called")
					return MisspelledForever_Saved_CTL_SendChatMessage(ChatThrottleLib, prio, prefix, text, ...)
				end
				MisspelledForever_CTL_hookedversion=ChatThrottleLib.version
			end
		end
	end
end

--Patch 3.5 Hook ChatFrame.lua ChatEdit_ActivateChat(editBox)
function MisspelledForever:ChatEdit_ActivateChat(editBox)
	--Make sure this editbox is hooked
	--print("EditBox to hook: " .. editBox:GetName())
	local hooked, hookHandler  = MisspelledForever:IsHooked(editBox, "OnTextChanged")
	if  hooked == false then
		MisspelledForever:WireUpEditBox(editBox)
	end

	self.hooks["ChatEdit_ActivateChat"](editBox)
end

--Before a chat message is sent, remove any highlighting that MisspelledForever might have added.
--The Wow client will disconnect if you attempt to send Hex code colored text in a chat message.
function MisspelledForever.SendChatMessage(message, chatType, languageID, target, ...)
	local cleanedMessage = MisspelledForever:RemoveHighlighting(message)

	--On DEBUG only
	--MisspelledForever:AddToInspector(cleanedMessage, "MisspelledForever:SendChatMessage - gotMessage")
	
	--self.hooks[C_ChatInfo]["SendChatMessage"](cleanedMessage, chatType, languageID, target, ...)
	if C_ChatInfo and MisspelledForever.hooks[C_ChatInfo] and MisspelledForever.hooks[C_ChatInfo]["SendChatMessage"] then
		MisspelledForever.hooks[C_ChatInfo]["SendChatMessage"](cleanedMessage, chatType, languageID, target, ...)
	elseif MisspelledForever.hooks["SendChatMessage"] then
        MisspelledForever.hooks["SendChatMessage"](cleanedMessage, chatType, languageID, target, ...)
	end
end

--Possible changes:
--A single new character was inserted at the end of the line (line length grew by 1)
--	  If this char is a word separator, then spell check the line
--
--Any other change in the line, requires we recheck the entire line.
--More than a single character was pasted or linked into the line.
--	remove any highlighting and recheck the entire line.
--
--A single character was removed from the line
function MisspelledForever.EditBox_OnTextChanged(editbox)
	if SkipOnTextChanged == true then
		SkipOnTextChanged = false
		return
	end

	--print("Editbox name:", editbox:GetName())

	--Load the guild roster if needed
	if GuildRosterCalled == false then
		if IsInGuild() then
			Compat.RequestGuildRoster() --Request updated guild roster info from the server
		else
			MisspelledForever:LoadGuildAndFriendRoster()
		end
		GuildRosterCalled = true
	end


	local text = editbox:GetText()
	local pos = editbox:GetCursorPosition()

	--print ("TextChaged:", editbox:GetCursorPosition(), string.gsub(editbox:GetText(), "\124", "\124\124"))

	local newLineLength = #text

	--Check if we should clear the WordCache table to save memory, if it's gotten very large
	if newLineLength == 0 then
		if WordCacheCount > WordCacheCountMax then
			WordCache = {}
			WordCacheCount = 0
		end
	end


	--if the first char is a /, indicating some slash command, skip spellchecking the text.
	if (string_sub(text, 1, 1) == "/" ) then
		local cleanedChatMessage = MisspelledForever:RemoveHighlighting(text)
		if text ~= cleanedChatMessage then
			editbox:SetText(cleanedChatMessage)
			if pos == 1 or pos== 0  then
			  editbox:SetCursorPosition(pos)
			end
			OldLineLength = #text
		end

		RightClickedWord = nil
		WordLocations[editbox:GetName()] = {}
		return
	end


	--If we currently just added one new char to the end of the line, see if it's a word boundary char
	--CursorPosition (pos) must be at the end of the line, and the line size must have had grown by
	--one character.
	if pos == #text and newLineLength -1 == OldLineLength then
		local lastChar = string_sub(text, -1, -1)
		if string_match(lastChar, "[ %(%);,%.!%?:\"]") ~= nil then
			MisspelledForever:SpellCheckChat(editbox)
		end
	elseif pos ~= #text then
		----We must be making some other kind of edit someplace other than at the end of the line.
		----Recheck the entire line
		MisspelledForever:SpellCheckChat(editbox)
	end

	--Save the new line length for use with the next round of OnTextChanged processing.
	OldLineLength = #editbox:GetText()
end

function MisspelledForever.EditBox_OnEscapePressed(editbox)
	RightClickedWord = nil
	WordLocations[editbox:GetName()] = {}
end

function MisspelledForever.EditBox_OnEnterPressed(editbox)
	RightClickedWord = nil
	WordLocations[editbox:GetName()] = {}

	--before message is sent, remove and misspelled highlighting
	local cleanedChatMessage = MisspelledForever:RemoveHighlighting(editbox:GetText())
	WordLocations[editbox:GetName()] = {}
	editbox:SetText(cleanedChatMessage)
end


--Return a string where misspelled words are highlighted
--If this string is a slash command "/", don't perform any highlighting
--We should keep track of the current edit cursor position,
--so we can report it's new position after highlighting.
function MisspelledForever:SpellCheckChat(editbox)
	local editboxText = editbox:GetText()

	if #editboxText < 2 then return end

	--Ensure we have hooked the MouseUp event
	--Should fix Chatter changing the OnMouseUp script to nil.  Bad Chatter
	local hooked, hookHandler  = MisspelledForever:IsHooked(editbox, "OnMouseUp")
	if  hooked == false or (hooked == true and hookHandler ~= self.OnMouseUp) then
		MisspelledForever:Unhook(editbox, "OnMouseUp")
		MisspelledForever:RawHookScript(editbox, "OnMouseUp", MisspelledForever.EditBox_OnMouseUp)
	end

	local newText = editboxText

	--Watch how many characters we insert or remove from the left side of the cursor position.
	--We'll adjust the cursor position to compensate for any misspelled word Hex code colored text added by MisspelledForever.
	local newCPos

	--remove any previous misspelling highlighting before checking the editboxText for misspellings.
	newText, newCPos = MisspelledForever:RemoveHighlighting(editboxText, editbox:GetCursorPosition())

	WordLocations[editbox:GetName()] = {}

	--If this is a command, don't spellcheck or highlight
	if string_sub(editboxText, 1, 1) == "/" then
		if newText ~= editboxText then
			editbox:SetText(newText)
			editbox:SetCursorPosition(newCPos)
		end
		return
	end

	if not self:IsChatTypeEnabled(self:GetEditBoxChatType(editbox)) then
		if newText ~= editboxText then
			editbox:SetText(newText)
			editbox:SetCursorPosition(newCPos)
		end
		return
	end

	--Find misspelled words & populate the WordLocations info.
	MisspelledForever:CheckLine(newText, editbox)

	local colorCodesAdded = 0
	--Use the WordLocation info to march backwards through the input text,
	--highlighting misspellings
	--tprint(WordLocations)
	local w
	for x = #WordLocations[editbox:GetName()], 1, -1 do
		w = WordLocations[editbox:GetName()][x]
		if WordCache[w.Word].Correct == false then
			--Insert highlighting
			newText = string_sub(newText, 1, w.StartPos -1) .. SPELLED_WRONG_HIGHLIGHT .. string_sub(newText, w.StartPos, w.EndPos) .. FONT_COLOR_CODE_CLOSE .. string_sub(newText, w.EndPos + 1)

			--Adjust cursor position if the cursor was to the right of the first char in the word we're highlighting.
			if newCPos >= w.EndPos then
				newCPos = newCPos + #SPELLED_WRONG_HIGHLIGHT + #FONT_COLOR_CODE_CLOSE
			elseif newCPos >= w.StartPos then
				newCPos = newCPos + #SPELLED_WRONG_HIGHLIGHT
			end

			colorCodesAdded = colorCodesAdded + 1
			if colorCodesAdded >= MaxColorCodes then 
				--Truncate WordLocations to here, because there are too many misspelled words.
				--The WoW chatbox won't let us add more than so many color coded sections.
				
				--Delete all entries before x
				WordLocations[editbox:GetName()] = { unpack( WordLocations[editbox:GetName()], x ) }
				
				break
			end
		end
	end

	--Adjust the word's WordLocation StartPos and EndPos, wherever we added highlighting.
	--The right click handler uses this position info. to detect the misspelled word that was right clicked.
	--March forward this time
	local n = 0 --NewCharsAddedCounter
	for x = 1, #WordLocations[editbox:GetName()] do
		w = WordLocations[editbox:GetName()][x]
		if WordCache[w.Word].Correct == false then
			w.StartPos = w.StartPos + n + #SPELLED_WRONG_HIGHLIGHT
			n = n + #SPELLED_WRONG_HIGHLIGHT
			w.EndPos = w.EndPos + n
			n = n + #FONT_COLOR_CODE_CLOSE
		end
	end

	if newText ~= editboxText then
		--When we call settext, an OnSetText event will fire.
		--Execution of this event should be skipped to avoid SpellCheckChat from running twice.
		--Use a local toggle to skip this second firing
		SkipOnTextChanged = true
		editbox:SetText(newText)
		editbox:SetCursorPosition(newCPos)
	end
end



--Finds all words in the input text string, ignoring any Wow hyperlinks or textures.
--These links or textures will be replaced with a sequence of # characters, the same length of the color+link,
--so the contents of these are not spellchecked.
--
--Next populate the table, WordLocations, storing the following info. on each word:
--	WordLocations[x] = {["word"] = word, ["StartPos"] = matchPosStart, ["EndPos"] = matchPosEnd}
--		x == Ordinal position of the word in the text string
--
--Next check each word to see we need to cache spell check info for the word.
--Words with numbers or words in all upper case are ignored.
--Store in the WordCache table whether the word is spell correctly, along with the
--any spelling replacement suggestions.
--
--Trim the WordCache table if it's grown very large
function MisspelledForever:CheckLine(text, editbox)
	--Reset the info on where each word is located
	WordLocations[editbox:GetName()] = {}

	if text == nil then return end
	if #text == 0 then return end

	--Find if there are any WoW UI escape sequences on this line, and replace them with # chars, 
	--so they don't match as words in the next stage of parsing and get ignored for spellchecking.
	--ref: https://warcraft.wiki.gg/wiki/UI_escape_sequences
	-- |cn[^:]+:.*|r          -- Global Colors text (new in 11.1.5 - |cncolorname:text|r)
	-- |cnIQ%d:.*|r           -- Item Quality Colors (new in 11.1.5 - |cnIQn:text|r
	-- |[Cc]%x-|H.+|h.+|h|r   -- Hex color coded text with links (format: |cffxxxxxx|Htype:payload|h[text]|h|r ) https://warcraft.wiki.gg/wiki/Hyperlinks
	-- |cn[^:]+:|H.+|h.+h|r   -- Global Colors / Custom item color links (new in 11.1.5 - |cncolorname:text|r) https://warcraft.wiki.gg/wiki/UI_escape_sequences#:~:text=back%20to%20white-,Global%20Colors,-%7Ccncolorname%3A
	-- |H.*|h                 -- Links
	-- |T.*|t                 -- Textures
	-- |A.*|a                 -- Texture Atlas
	-- {.-}                   -- Raid target icons
	-- |n                     -- newline character
	local newText = text
	-- newText = string_gsub(newText, "(|[Cc]%x-|H.-|h.-|h|r)", function(x) return string_rep("#", #x) end)
	-- newText = string_gsub(newText, "(|H.*|h)", function(x) return string_rep("#", #x) end)
	-- newText = string_gsub(newText, "(|T.*|t)", function(x) return string_rep("#", #x) end)
	-- newText = string_gsub(newText, "({.-})", function(x) return string_rep("#", #x) end)
	-- newText = string_gsub(newText, "(|n)", function(x) return string_rep("#", #x) end)

	local WowTextMarkupEscapes = {
		["(|cn[^:]+:.-|r)"] = "#",        -- Global Colors text
		["(|cnIQ%d:.-|r)"] = "#",         -- Item Quality Colors text
		["(|[Cc]%x-|H.-|h.-|h|r)"] = "#", -- Hex color coded text with optional colored links
		["(|H.-|h)"] = "#",               -- Links
		["(|T.-|t)"] = "#",               -- Textures
		["(|A.-|a)"] = "#",               -- Texture Atlas
		["({.-})"] = "#",                 -- Raid target icons
		["(|n)"] = "#"                    -- Newline character
	}

	for k, v in pairs(WowTextMarkupEscapes) do
        newText = string_gsub(newText, k, function(x) return string_rep(v, #x) end)
    end

	--March through the text, finding the words, record there start & end positions, and spell check status
	local patt = "[A-Za-z0-9_'À-ÿœæŒÆ]+"
	local matchPosStart
	local matchPosEnd

	matchPosStart, matchPosEnd = string_find(newText, patt)

	local x = 0
	local word
	local correct
	while matchPosStart ~= nil do
		word = string_sub(newText, matchPosStart, matchPosEnd)

		--ignore all uppercase words
		if word ~= string_upper(word) then
			--ignore words with numbers in them
			if string_match(word, "[%d]") == nil then
				x = x + 1
				WordLocations[editbox:GetName()][x] = {["Word"] = word, ["StartPos"] = matchPosStart, ["EndPos"] = matchPosEnd}

				if WordCache[word] == nil then
					correct = false

					--Ignore words in all upper case
					if word == string_upper(word) then
						correct = true
					end

					--See if the dictionary contains the word
					if correct == false then
						correct = WordDict:Contains(word)
					end

					--Try the lower case version of the word
					if correct == false then
						correct = WordDict:Contains(string_lower(word))
					end

					--Cache the results
					WordCache[word] = {["Correct"] = correct} --, ["Suggestions"] = {}}
					WordCacheCount = WordCacheCount + 1
					--Changed to delay searching for suggestions until someone right-clicks on a misspelled word.
					--Adding UTF8 support slows the suggestion generation.
--~ 					if correct == false then
--~ 						local suggestions = {}
--~ 						suggestions = WordDict:Suggest(word)
--~ 						if #suggestions > 0 then
--~ 							WordCache[word].Suggestions = suggestions
--~ 						end
--~ 					end
				end
			end
		end

		matchPosStart, matchPosEnd = string_find(newText, patt, matchPosEnd+1)
	end
end



--Return a string where the highlighting has been removed from any misspelled words,
--with the goal to not change or destroy any other UI escaped sequences present in the chat message,
--such as colored text, Wow itemLinks or textures. 
--(https://warcraft.wiki.gg/wiki/UI_escape_sequences & http://www.wowwiki.com/ItemLink)
--
--misspelled word highlighting is added with a Hex color coded UI escape sequence: |cff7dc6fbHighlightedText|r
--The chat message text may contain other UI escaped sequences such at item links.
--The chat message text could also contain one or more pipe characters ||, complicating parsing.
--
-- Note: Lua's standard regular expression library has limitations compared to some other regex engines.
-- It does not support features like negative lookahead assertions ((?!...)),
-- which are typically used to assert that a sequence is not present.
-- Therefore, a single Lua regular expression cannot directly say "match everything until |r, but fail if |h is encountered before that".
--
--Potential refactor: 
-- 1) Use a regular expression to match any block starting with |cff7dc6fb and ending with |r, capturing everything in between.
--    regex capture: |c%x-(.-)|r
-- 2) Check the captures text to ensure it does not contain the sequence |h.
--
--It's possible that a recent edit has started to destroy the color tags, either at the
--beginning or end of a highlighted misspelled word.
--Attempt to detect this and remove any dangling colored text tags.
function MisspelledForever:RemoveHighlighting(text, ...)
	-- \124 is the ASCII code for the pipe '|' character.
	--MisspelledForever:AddToInspector(string_gsub(text, "\124", "\124\124"), "RemoveHighlighting-input")
	--Blizzard uses string.gsub(textString, "[|]", "||"), in the /dump source code 
	
	local cleanedChatMessage
	local newText = text

	--Track the number of characters removed from the left side of the current cursor position.
	local cPos
	if ... ~= nil then
		cPos = ...
	else
		cPos = 0
	end

	local itemLinks = {}
	local itemLink
	local itemLinkNum = 1

	local patt, matchPosStart, matchPosEnd
	local tokenSize
	local tempToken
	local tempText
	local charsRemoved  --Tracks the chars removed from the left of the cursor

	--Try and match Global Colors text. (|cncolorname:text|r)
	--Use a non-greedy match character (-) in the match pattern rather than a greed match character (*)
	patt = "(|cn[^:]+:.-|r)"
	matchPosStart, matchPosEnd = string_find(newText, patt)

	while matchPosStart ~= nil do
		--Store the itemlink and it's relative position so it can be replaced latter
		itemLink = string_sub(newText, matchPosStart, matchPosEnd)
		itemLinks[itemLinkNum] = itemLink

		tokenSize = #itemLink
		tempToken = "{<<" .. tostring(itemLinkNum)
		tempToken = tempToken .. string_rep(">", tokenSize - #tempToken - 1) .. "}"

		--Replace this itemlink with a temporary placeholder code
		newText = string_gsub(newText, patt, tempToken, 1)

		itemLinkNum = itemLinkNum + 1
		matchPosStart, matchPosEnd = string_find(newText, patt)
	end

	--Try and match (IQn) Item Quality Colors text. (|cnIQn:text|r)
	--Use a non-greedy match character (-) in the match pattern rather than a greed match character (*)
	patt = "(|cnIQ%d:.-|r)"
	matchPosStart, matchPosEnd = string_find(newText, patt)

	while matchPosStart ~= nil do
		--Store the itemlink and it's relative position so it can be replaced latter
		itemLink = string_sub(newText, matchPosStart, matchPosEnd)
		itemLinks[itemLinkNum] = itemLink

		tokenSize = #itemLink
		tempToken = "{<<" .. tostring(itemLinkNum)
		tempToken = tempToken .. string_rep(">", tokenSize - #tempToken - 1) .. "}"

		--Replace this itemlink with a temporary placeholder code
		newText = string_gsub(newText, patt, tempToken, 1)

		itemLinkNum = itemLinkNum + 1
		matchPosStart, matchPosEnd = string_find(newText, patt)
	end

	--Try and match Hex code colored Item links.  The Addon GHI (Gryphonheart Items) colors links with a capitol C, non-standard.
	patt = "|[Cc]%x+|H.-|h.-|h|r"
	matchPosStart, matchPosEnd = string_find(newText, patt)

	while matchPosStart ~= nil do
		--Store the itemlink and it's relative position so it can be replaced latter
		itemLink = string_sub(newText, matchPosStart, matchPosEnd)
		itemLinks[itemLinkNum] = itemLink

		tokenSize = #itemLink
		tempToken = "{<<" .. tostring(itemLinkNum)
		tempToken = tempToken .. string_rep(">", tokenSize - #tempToken - 1) .. "}"

		--Replace this itemlink with a temporary placeholder code
		newText = string_gsub(newText, patt, tempToken, 1)

		itemLinkNum = itemLinkNum + 1
		matchPosStart, matchPosEnd = string_find(newText, patt)
	end

	--Try to match, non-colored Item Links
	patt = "|H.-|h"
	matchPosStart, matchPosEnd = string_find(newText, patt)

	while matchPosStart ~= nil do
		--Store the itemlink and it's relative position so it can be replaced latter
		itemLink = string_sub(newText, matchPosStart, matchPosEnd)
		itemLinks[itemLinkNum] = itemLink

		tokenSize = #itemLink
		tempToken = "{<<" .. tostring(itemLinkNum)
		tempToken = tempToken .. string_rep(">", tokenSize - #tempToken - 1) .. "}"

		--Replace this itemlink with a temporary placeholder code
		newText = string_gsub(newText, patt, tempToken, 1)

		itemLinkNum = itemLinkNum + 1
		matchPosStart, matchPosEnd = string_find(newText, patt)
	end

	--Try to match and textures links.  (i.e. Raid targets and there used when chatting with a GM)
	patt = "|T.-|t"
	matchPosStart, matchPosEnd = string_find(newText, patt)

	while matchPosStart ~= nil do
		--Store the itemlink and it's relative position so it can be replaced latter
		itemLink = string_sub(newText, matchPosStart, matchPosEnd)
		itemLinks[itemLinkNum] = itemLink

		tokenSize = #itemLink
		tempToken = "{<<" .. tostring(itemLinkNum)
		tempToken = tempToken .. string_rep(">", tokenSize - #tempToken - 1) .. "}"

		--Replace this itemlink with a temporary placeholder code
		newText = string_gsub(newText, patt, tempToken, 1)

		itemLinkNum = itemLinkNum + 1
		matchPosStart, matchPosEnd = string_find(newText, patt)
	end


	--Remove the highlighting from any misspelled words.
	--i.e. When the beginning SPELLED_WRONG_HIGHLIGHT Hex coded color tag and ending |r tag wrap text.
	--Adjust the cursor position as needed.
	patt = SPELLED_WRONG_HIGHLIGHT .. "(.-)|r"

	matchPosStart, matchPosEnd = string_find(newText, patt)

	MisspelledForever:AddToInspector({_patt=string_gsub(patt,"[|]","||"),_newText=string_gsub(newText,"[|]","||"),_matchPosStart=matchPosStart,_matchPosEnd=matchPosEnd},"RemoveHighlighting string.find misspelled highlighting")

	while matchPosStart ~= nil do
		--strings.gsub(input, pattern, replaceText, n=limit the number of substations to be made)
		tempText = string_gsub(newText, patt, "%1", 1)
		--tempText = string_gsub(newText, patt, function(x) return x end, 1)

		if #newText - #tempText ~= 0 then
			charsRemoved = 0
			--If the cursor was to the right of the start, subtract the num of deleted chars from the cursor position
			if cPos >= matchPosStart then
				charsRemoved = (#newText - #tempText)
			end
			--If the cursor was to the left of the end color tag and to the right of the start, add 2
			if cPos >= matchPosStart and cPos < matchPosEnd then
				charsRemoved = charsRemoved - 2
			end
			cPos = cPos - charsRemoved
		end
		newText = tempText

		matchPosStart, matchPosEnd = string_find(newText, patt)
	end

	--Remove any remaining orphaned beginning color tags.
	patt = "|[Cc]%x%x%x%x%x%x%x%x"
	matchPosStart, matchPosEnd = string_find(newText, patt)
	while matchPosStart ~= nil do
		tempText = string_gsub(newText, patt, "", 1)

		if #newText - #tempText ~= 0 then
			--If the cursor was to the right of the start, subtract the num of deleted chars from the cursor position
			if cPos >= matchPosStart then
				cPos = cPos - (#newText - #tempText)
			end
		end
		newText = tempText

		matchPosStart, matchPosEnd = string_find(newText, patt)
	end

	--Remove any remaining orphaned ending color tags.
	patt = "|r"
	matchPosStart, matchPosEnd = string_find(newText, patt)
	while matchPosStart ~= nil do
		tempText = string_gsub(newText, patt, "", 1)

		if #newText - #tempText ~= 0 then
			--If the cursor was to the right of the start, subtract the num of deleted chars from the cursor position
			if cPos >= matchPosStart then
				cPos = cPos - (#newText - #tempText)
			end
		end
		newText = tempText

		matchPosStart, matchPosEnd = string_find(newText, patt)
	end

	--Replace back the escape sequences extracted
	if #itemLinks > 0 then
		for i,val in ipairs(itemLinks) do
			newText = string_gsub(newText, "{<<" .. tostring(i) .. ">-}", val)
		end
	end


	--If by chance the tracked cursor position went negative, set it to 0
	if cPos < 0 then
		cPos = 0
	end

	
	cleanedChatMessage = newText
	--cPos should never be > #newText, unless there's some unfound error above
	return cleanedChatMessage, cPos
end

function MisspelledForever:TestRemoveHighlighting()
	local testMessage
	local checkMessage
	local cleanedMessage
	local newCPos
	local testResult

	--Test 1
	testID = "1"
	testMessage = "Apple"
	checkMessage= "Apple"
	cleanedMessage, newCPos = MisspelledForever:RemoveHighlighting(testMessage, string_len(testMessage))

	local testResults_table = {
		_testMessage = string_gsub(testMessage,"[|]","||"),
		_checkMessage = string_gsub(checkMessage,"[|]","||"),
		_cleanedMessage = string_gsub(cleanedMessage,"[|]","||"),
		_CPos = string_len(testMessage),
		_newCPos = newCPos
	}

	if cleanedMessage == checkMessage then testResult = "passed" else testResult = "failed" end
    MisspelledForever:AddToInspector(testResults_table,"Test ".. testResult .. ": RemoveHighlighting "..testID)
	
	--Test2 - misspelled highlighted word: Applez
	testID = "2"
	testMessage = "|cff7dc6fbApplez|r"
	checkMessage= "Applez"
	cleanedMessage, newCPos = MisspelledForever:RemoveHighlighting(testMessage, string_len(testMessage))

	local testResults_table = {
		_testMessage = string_gsub(testMessage,"[|]","||"),
		_checkMessage = string_gsub(checkMessage,"[|]","||"),
		_cleanedMessage = string_gsub(cleanedMessage,"[|]","||"),
		_CPos = string_len(testMessage),
		_newCPos = newCPos
	}

	if cleanedMessage == checkMessage then testResult = "passed" else testResult = "failed" end
    MisspelledForever:AddToInspector(testResults_table,"Test ".. testResult .. ": RemoveHighlighting "..testID)
	
	--Test3 - misspelled highlighted word: Applez good.
	testID = "3"
	testMessage = "|cff7dc6fbApplez|r good."
	checkMessage= "Applez good."
	cleanedMessage, newCPos = MisspelledForever:RemoveHighlighting(testMessage, string_len(testMessage))

	local testResults_table = {
		_testMessage = string_gsub(testMessage,"[|]","||"),
		_checkMessage = string_gsub(checkMessage,"[|]","||"),
		_cleanedMessage = string_gsub(cleanedMessage,"[|]","||"),
		_CPos = string_len(testMessage),
		_newCPos = newCPos
	}

	if cleanedMessage == checkMessage then testResult = "passed" else testResult = "failed" end
    MisspelledForever:AddToInspector(testResults_table,"Test ".. testResult .. ": RemoveHighlighting "..testID)

	--Test4 - Correctly spelled word [Link] correctly spelled word
	testID = "4"
	testMessage = "Test |cff71d5ff|Hspell:2061:0|h[Flash Heal]|h|r good."
	checkMessage= "Test |cff71d5ff|Hspell:2061:0|h[Flash Heal]|h|r good."
	cleanedMessage, newCPos = MisspelledForever:RemoveHighlighting(testMessage, string_len(testMessage))

	local testResults_table = {
		_testMessage = string_gsub(testMessage,"[|]","||"),
		_checkMessage = string_gsub(checkMessage,"[|]","||"),
		_cleanedMessage = string_gsub(cleanedMessage,"[|]","||"),
		_CPos = string_len(testMessage),
		_newCPos = newCPos
	}

	if cleanedMessage == checkMessage then testResult = "passed" else testResult = "failed" end
	MisspelledForever:AddToInspector(testResults_table,"Test ".. testResult .. ": RemoveHighlighting "..testID)

	--Test5 - Correctly spelled word [Spell Link] incorrectly spelled word
	testID = "5"
	testMessage = "Test |cff71d5ff|Hspell:2061:0|h[Flash Heal]|h|r |cff7dc6fbbadd|r."
	checkMessage= "Test |cff71d5ff|Hspell:2061:0|h[Flash Heal]|h|r badd."
	cleanedMessage, newCPos = MisspelledForever:RemoveHighlighting(testMessage, string_len(testMessage))

	local testResults_table = {
		_testMessage = string_gsub(testMessage,"[|]","||"),
		_checkMessage = string_gsub(checkMessage,"[|]","||"),
		_cleanedMessage = string_gsub(cleanedMessage,"[|]","||"),
		_CPos = string_len(testMessage),
		_newCPos = newCPos
	}

	if cleanedMessage == checkMessage then testResult = "passed" else testResult = "failed" end
	MisspelledForever:AddToInspector(testResults_table,"Test ".. testResult .. ": RemoveHighlighting "..testID)

	--Test6 - Correctly spelled word [Item link]
	testID = "6"
	testMessage = "Off-hand: |cffa335ee|Hitem:222566::::::::80:258::13:1:3524:6:40:2249:38:8:45:211296:46:226024:47:222584:48:224072:::::|h[Vagabond's Torch |A:Professions-ChatIcon-Quality-Tier5:17:17::1|a]|h|r"
	checkMessage= "Off-hand: |cffa335ee|Hitem:222566::::::::80:258::13:1:3524:6:40:2249:38:8:45:211296:46:226024:47:222584:48:224072:::::|h[Vagabond's Torch |A:Professions-ChatIcon-Quality-Tier5:17:17::1|a]|h|r"
	cleanedMessage, newCPos = MisspelledForever:RemoveHighlighting(testMessage, string_len(testMessage))

	local testResults_table = {
		_testMessage = string_gsub(testMessage,"[|]","||"),
		_checkMessage = string_gsub(checkMessage,"[|]","||"),
		_cleanedMessage = string_gsub(cleanedMessage,"[|]","||"),
		_CPos = string_len(testMessage),
		_newCPos = newCPos
	}

	if cleanedMessage == checkMessage then testResult = "passed" else testResult = "failed" end
	MisspelledForever:AddToInspector(testResults_table,"Test ".. testResult .. ": RemoveHighlighting "..testID)
	
	--Test7 - Correctly spelled word [Hex colored Item link] incorrectly spelled word.
	testID = "7"
	testMessage = "Off-hand: |cffa335ee|Hitem:222566::::::::80:258::13:1:3524:6:40:2249:38:8:45:211296:46:226024:47:222584:48:224072:::::|h[Vagabond's Torch |A:Professions-ChatIcon-Quality-Tier5:17:17::1|a]|h|r |cff7dc6fbbadd|r."
	checkMessage= "Off-hand: |cffa335ee|Hitem:222566::::::::80:258::13:1:3524:6:40:2249:38:8:45:211296:46:226024:47:222584:48:224072:::::|h[Vagabond's Torch |A:Professions-ChatIcon-Quality-Tier5:17:17::1|a]|h|r badd."
	cleanedMessage, newCPos = MisspelledForever:RemoveHighlighting(testMessage, string_len(testMessage))

	local testResults_table = {
		_testMessage = string_gsub(testMessage,"[|]","||"),
		_checkMessage = string_gsub(checkMessage,"[|]","||"),
		_cleanedMessage = string_gsub(cleanedMessage,"[|]","||"),
		_CPos = string_len(testMessage),
		_newCPos = newCPos
	}

	if cleanedMessage == checkMessage then testResult = "passed" else testResult = "failed" end
	MisspelledForever:AddToInspector(testResults_table,"Test ".. testResult .. ": RemoveHighlighting "..testID)

	--Test8 - Correctly spelled word [cnIQ#: colored Item link]
	testID = "8"
	testMessage  = "test: |cnIQ2:|Hitem:225566::::::::80:258:::::::::|h[Warped Wing]|h|r"
	checkMessage = "test: |cnIQ2:|Hitem:225566::::::::80:258:::::::::|h[Warped Wing]|h|r"
	cleanedMessage, newCPos = MisspelledForever:RemoveHighlighting(testMessage, string_len(testMessage))

	local testResults_table = {
		_testMessage = string_gsub(testMessage,"[|]","||"),
		_checkMessage = string_gsub(checkMessage,"[|]","||"),
		_cleanedMessage = string_gsub(cleanedMessage,"[|]","||"),
		_CPos = string_len(testMessage),
		_newCPos = newCPos
	}

	if cleanedMessage == checkMessage then testResult = "passed" else testResult = "failed" end
	MisspelledForever:AddToInspector(testResults_table,"Test ".. testResult .. ": RemoveHighlighting "..testID)

	--Test9 - Correctly spelled word [cnIQ#: colored Item link] incorrectly spelled word.
	testID = "9"
	testMessage  = "test: |cnIQ2:|Hitem:225566::::::::80:258:::::::::|h[Warped Wing]|h|r |cff7dc6fbbadd|r."
	checkMessage = "test: |cnIQ2:|Hitem:225566::::::::80:258:::::::::|h[Warped Wing]|h|r badd."
	cleanedMessage, newCPos = MisspelledForever:RemoveHighlighting(testMessage, string_len(testMessage))

	local testResults_table = {
		_testMessage = string_gsub(testMessage,"[|]","||"),
		_checkMessage = string_gsub(checkMessage,"[|]","||"),
		_cleanedMessage = string_gsub(cleanedMessage,"[|]","||"),
		_CPos = string_len(testMessage),
		_newCPos = newCPos
	}

	if cleanedMessage == checkMessage then testResult = "passed" else testResult = "failed" end
	MisspelledForever:AddToInspector(testResults_table,"Test ".. testResult .. ": RemoveHighlighting "..testID)
end

-------------------------------------------------------------------------
--
-- Routines for the right click MisspelledForever suggestions popup.
--
-------------------------------------------------------------------------
function MisspelledForever:OnMouseUp(editbox, button)
	if button == "RightButton" then
		local badWordFound = false
		CloseDropDownMenus()

		--check if we are positioned on a misspelled word
		local pos = editbox:GetCursorPosition()
		if WordLocations[editbox:GetName()] ~= nil then
			for i, w in ipairs(WordLocations[editbox:GetName()]) do
				if	pos >= w.StartPos and pos <= w.EndPos then
					if WordCache[w.Word].Correct == false then
						--If not cached, lookup Suggestions for the misspelled word
						if WordCache[w.Word].Suggestions == nil then
							WordCache[w.Word].Suggestions = WordDict:Suggest(w.Word)
						end

						RightClickedWord = w.Word
						RightClickedWordStartPos = w.StartPos
						RightClickedWordEndPos = w.EndPos

						RightClickedEditBox = editbox

						badWordFound = true

						local menuXOffset = MisspelledForever:GetSuggestionMenuXOffset(editbox, pos, w.EndPos)
						ToggleDropDownMenu(1, nil, MisspelledForeverSuggestions_DropDown, "cursor", menuXOffset, 0)
					else
						RightClickedWord = nil
					end
					break
				end
			end
		end

		--Show where the user right clicked.
		--print("cursor position:" , ChatFrameEditBox:GetCursorPosition())

		--If we are not positioned on a bad, word call and MouseUp handler that was hooked to the box.
		if badWordFound == false then
			--print("Trigger native OnMouseUp call")
			self.hooks[editbox]["OnMouseUp"](editbox, button)
		end
	end
end

function MisspelledForeverSuggestions_InitializeDropDown(level)
	if RightClickedWord == nil then return end
	if #RightClickedWord == 0 then return end

	do
	  local info = UIDropDownMenu_CreateInfo()
	info.text = L["Suggestions for:"] .. " " .. RightClickedWord
	info.isTitle = 1
	info.notClickable = 1
	info.notCheckable = true
	UIDropDownMenu_AddButton(info)
	end

	--Add suggestions to the DropDown
	for i, s in ipairs(WordCache[RightClickedWord].Suggestions) do
		do
			local info = UIDropDownMenu_CreateInfo()
                --Line below causes a this == nil error in 4.0.  Looks like it's not needed.
		--info.owner = this:GetParent()

		--If the misspelled word's first
		info.text = s.Word

		--If this suggestion is either a guild member or friend append a note.
		if MisspelledForever:IsGuildMember(s.Word) == true then
			info.text = info.text .. " " .. L["(Guild)"]
		else
			if MisspelledForever:IsFriend(s.Word) == true then
				info.text = info.text .. " " .. L["(Friend)"]
			end
		end

		info.isTitle = nil
		info.notCheckable = true
		info.value = s.Word
		info.func = function() SuggestionsFrame_Click(s.Word, RightClickedEditBox) end
		--Add the above info to the options menu as clickable item
		UIDropDownMenu_AddButton(info)
		end
	end

	do
		--Add a non-clickable separator
		local info = UIDropDownMenu_CreateInfo()
	--info.owner = this:GetParent()
	info.text = ""
	info.isTitle = nil
	info.value = ""
	info.notClickable = 1
	info.notCheckable = true
	UIDropDownMenu_AddButton(info)
	end

	do
		local info = UIDropDownMenu_CreateInfo()
	--info.owner = this:GetParent()
	info.text = L["Ignore All"]
	info.isTitle = nil
	info.value = RightClickedWord
	info.func = function() SuggestionsFrame_Click("###IgnoreAll", RightClickedEditBox) end
	info.notClickable = nil
	info.notCheckable = true
	UIDropDownMenu_AddButton(info)
	end

	do
		local info = UIDropDownMenu_CreateInfo()
	--info.owner = this:GetParent()
	info.text = L["Add to Dictionary"]
	info.isTitle = nil
	info.value = RightClickedWord
	info.func = function() SuggestionsFrame_Click("###AddToDictionary", RightClickedEditBox) end
	info.notClickable = nil
	info.notCheckable = true
	UIDropDownMenu_AddButton(info)
	end

	do
		local info = UIDropDownMenu_CreateInfo()
	--info.owner = this:GetParent()
	info.text = L["Cancel"]
	info.isTitle = nil
	info.value = nil
	info.notClickable = nil
	info.notCheckable = true
	UIDropDownMenu_AddButton(info)
	end
end

function MisspelledForeverSuggestions_DropDownOnLoad(self)
	UIDropDownMenu_Initialize(self, MisspelledForeverSuggestions_InitializeDropDown, "MENU")
end

function SuggestionsFrame_Click(value, editbox)
	--value will equal the suggestion word clicked,
	--or a "special" tag, for the 'Ignore' and 'Add to Dictionary' functions

	--print("Suggestion Clicked: ", value)

	local newText = editbox:GetText()
	local newCursorPos = nil

	local isCapitalizedRightClickedWord = false

	--Check if the local (global) var RightClickedWord is populated with a non nil value
    assert(RightClickedWord ~= nil, "MisspelledForever: SuggestionsFrame_Click, Unexpected: RightClickedWord == nil")

	if string_sub(RightClickedWord, 1, 1) == string_upper(string_sub(RightClickedWord, 1, 1)) then
		isCapitalizedRightClickedWord = true
	end

	if value == "###IgnoreAll" then
		--Add this word to the WordCache so it will be ignored as misspelled until you reload
		--print("Ignore:", RightClickedWord)
		WordCache[RightClickedWord].Correct = true
		WordCache[RightClickedWord].Suggestions = {}

		--Remove the misspelled highlighting
		newText = string_sub(newText, 1, RightClickedWordStartPos - 1 - #SPELLED_WRONG_HIGHLIGHT) .. RightClickedWord .. string_sub(newText, RightClickedWordEndPos + #FONT_COLOR_CODE_CLOSE + 1)
		newCursorPos = RightClickedWordStartPos + #RightClickedWord - #SPELLED_WRONG_HIGHLIGHT - #FONT_COLOR_CODE_CLOSE + 1

	elseif value == "###AddToDictionary" then
		-- Add this word to the user dictionary
		--print("Add to UserDict", RightClickedWord)
		MisspelledForever:AddToUserDict(RightClickedWord)
		WordCache[RightClickedWord].Correct = true
		WordCache[RightClickedWord].Suggestions = {}

		--Remove the misspelled highlighting
		newText = string_sub(newText, 1, RightClickedWordStartPos - 1 - #SPELLED_WRONG_HIGHLIGHT) .. RightClickedWord .. string_sub(newText, RightClickedWordEndPos + #FONT_COLOR_CODE_CLOSE + 1)
		newCursorPos = RightClickedWordStartPos + #RightClickedWord - #SPELLED_WRONG_HIGHLIGHT - #FONT_COLOR_CODE_CLOSE + 1

	else
		--replace this word with the selected suggestion.
		--Remove the misspelled highlighting in the process.
		--
		--If the misspelled word was capitalized, capitalize the replacement.
		if isCapitalizedRightClickedWord == true then
			value = string_upper(string_sub(value, 1, 1)) .. string_sub(value, 2)
		end
		newText = string_sub(newText, 1, RightClickedWordStartPos - 1 - #SPELLED_WRONG_HIGHLIGHT) .. value .. string_sub(newText, RightClickedWordEndPos + #FONT_COLOR_CODE_CLOSE + 1)

		--save the cursor position just after the corrected word, so we can set it later
		newCursorPos = RightClickedWordStartPos + #value - #SPELLED_WRONG_HIGHLIGHT - #FONT_COLOR_CODE_CLOSE + 1

		--Note: if the replacement word is a different length, then the WordLocations will be messed up.
	end

	editbox:SetText(newText)

	--printable = gsub(newText, "\124", "\124\124")  --\124 == "|"
    --print("New ChatText:", printable)

	--If we replaced a word, with a suggestion, move the cursor to the end of the new word.
	if newCursorPos ~= nil then
		--Check if the character to the right of the cursor is a space.  If so adjust the cursor to the right by 1 char.
		if #newText > newCursorPos then
			if string_sub(newText, newCursorPos + 1, newCursorPos + 1) == " " then
				newCursorPos = newCursorPos + 1
			end
		end

		editbox:SetCursorPosition(newCursorPos)
	end

	RightClickedWord = nil
end
-----------------------------------------------------
-- End: Right click Suggestions popup
-----------------------------------------------------



-------------------------------------------------------------------------
--
-- Routines for dealing with the user dictionary
--
-------------------------------------------------------------------------

--Load the words saved in the Users dictionary into the baseWords table.
--In r18 we changed the in memory format used to store the baseWords, affixCode and PhoneticCode,
--Saved a ton of memory not using a sub-table per baseWord.
--If necessary convert the user dictionary storage to match the newer format.
function MisspelledForever:LoadUserDict()
	local db = EnsureDB()

	local affixKeys, pCode
	if db.UserDict ~= nil then
		for k, v in pairs(db.UserDict) do
			--If needed convert the user dictionary format to the, post r18 format.
			if type(v) == "table" then
				affixKeys = v[1]
				pCode = v[2]
				if affixKeys == nil then affixKeys = "" end
				if pCode == nil then pCode = "" end
				v = affixKeys .. "/" .. pCode
				db.UserDict[k] = v
			end

			if WordDict.baseWords[k] == nil then
				WordDict.baseWords[k] = v
			end
		end
	end
end


--Add a new word to the users dictionary, and the currently loaded baseWords table.
--Store both the word and it's phonetic code.
function MisspelledForever:AddToUserDict(word)
	if word == nil then return end
	if #word == 0 then return end

	EnsureDB()
	self:AddWordToDictionary(word, true)

	--Fixup the WordCache
	WordCache[word] = WordCache[word] or {}
	WordCache[word].Correct = true
	WordCache[word].Suggestions = {}
end

function MisspelledForever:ImportUserDict(text)
	local db = EnsureDB()
	local imported = 0
	for word in string_gmatch(text or "", "[^,%s;]+") do
		if #word > 0 and db.UserDict[word] == nil then
			self:AddToUserDict(word)
			imported = imported + 1
		end
	end
	self:ClearWordCache()
	return imported
end

function MisspelledForever:ExportUserDict()
	local db = EnsureDB()
	local words = {}
	for word in pairs(db.UserDict) do
		table_insert(words, word)
	end
	table.sort(words)
	return table.concat(words, "\n")
end

function MisspelledForever:OpenUserDictTransfer(mode)
	local exportMode = mode == "export"
	local frame = AceGUI:Create("Window")
	frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
	frame:SetLayout("Flow")
	frame:SetWidth(420)
	frame:SetHeight(360)
	frame:SetTitle(exportMode and "MisspelledForever - Export User Dictionary" or "MisspelledForever - Import User Dictionary")

	local box = AceGUI:Create("MultiLineEditBox")
	box:SetFullWidth(true)
	box:SetNumLines(12)
	box:DisableButton(true)
	box:SetLabel(exportMode and "Copy these words:" or "Paste words separated by spaces, commas, semicolons, or new lines:")
	box:SetText(exportMode and self:ExportUserDict() or "")
	frame:AddChild(box)

	if not exportMode then
		local importButton = AceGUI:Create("Button")
		importButton:SetText("Import")
		importButton:SetCallback("OnClick", function()
			local imported = self:ImportUserDict(box:GetText())
			self:print("Imported " .. imported .. " user dictionary word(s).")
			frame:Hide()
		end)
		frame:AddChild(importButton)
	end
end


local MisspelledForever_Words_To_Delete = {}

function MisspelledForever:EditUserDict()
	local gui = AceGUI

	local f = AceGUI:Create("Window")
	f:SetCallback("OnClose",function(widget, event) AceGUI:Release(widget) end )
	f:SetLayout("Flow")
	f:SetWidth(300)
	f:SetHeight(490)
	f:SetTitle("MisspelledForever - " .. L["User Dictionary"])
	f:ReleaseChildren()
	f:PauseLayout()


	MisspelledForever_Words_To_Delete = {}

	local i = gui:Create("InlineGroup")
	i:SetLayout("List")
	i:SetFullWidth(true)
	i:SetHeight(370)
	i:SetTitle(L["Select words to remove:"])
	f:AddChild(i)

	local scroll = AceGUI:Create("ScrollFrame")
	scroll:SetLayout("Flow")
	scroll:SetFullWidth(true)
	scroll:SetHeight(370)
	i:AddChild(scroll)

	local delButton = AceGUI:Create("Button")
	delButton:SetText("Delete")
	delButton:SetCallback("OnClick", function()
		PlaySound(856) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
		--Delete selected words from the user dictionary
		MisspelledForever:print("MisspelledForever: " .. L["Removing the following words from the user dictionary"])
		for k,v in pairs(MisspelledForever_Words_To_Delete) do
			MisspelledForever:print(" - " .. k)
			MisspelledForever_DB.UserDict[k] = nil

			--Remove the word from the, in memory dictionary
			WordDict.baseWords[k] = nil
		end

		--Clear the word cache
		WordCache = {}
		WordCacheCount = 0

		delButton:SetDisabled(true)
		f:Hide()
	end )
	delButton:SetDisabled(true)

	f:AddChild(delButton)

	local exportButton = AceGUI:Create("Button")
	exportButton:SetText("Export")
	exportButton:SetCallback("OnClick", function()
		MisspelledForever:OpenUserDictTransfer("export")
	end)
	f:AddChild(exportButton)

	local importButton = AceGUI:Create("Button")
	importButton:SetText("Import")
	importButton:SetCallback("OnClick", function()
		MisspelledForever:OpenUserDictTransfer("import")
	end)
	f:AddChild(importButton)

	--Check if the UserDict exist.  If not initialize it, creating a blank user dictionary.
	local db = EnsureDB()

	for k, v in pairs(db.UserDict) do
		local x = AceGUI:Create("InteractiveLabel")
		x:SetHighlight(.3,.3,.3,.5  )
		x:SetFullWidth(true)
		x:SetText(k)

		x:SetCallback("OnClick", function (widget, event, text)
			--print("Clicked: " .. widget.label:GetText())

			PlaySound(856) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
			--Check if item is selected or not
			local r,g,b,a = widget.label:GetTextColor()

			if b == 0 then
				--Selected, process an unselect
				widget:SetColor(1,1,1,1)
				MisspelledForever_Words_To_Delete[widget.label:GetText()] = nil
				local x = 0
				for k,v in pairs(MisspelledForever_Words_To_Delete) do
					x = x + 1
				end

				if x == 0 then
					delButton:SetDisabled(true)
				else
					delButton:SetDisabled(false)
				end
			else	--Unselected, process a select
				widget:SetColor(1,.2,0,1)
				MisspelledForever_Words_To_Delete[widget.label:GetText()] = 1
				delButton:SetDisabled(false)
			end
		end )

		scroll:AddChild(x)
	end


	f:ResumeLayout()
	f:DoLayout()
	f:Show()
end

-------------------------------------------------------------------------
-- End: Routines for dealing with the user dictionary
-------------------------------------------------------------------------



-------------------------------------------------------------------------
--
-- Load Guild and Friend Roster Routine
--
-------------------------------------------------------------------------

--Load the player's guild members and friends, as valid words into the
--loaded dictionary.
function MisspelledForever:LoadGuildAndFriendRoster()

	local numFriends, friendName
	FriendNameCache = {}
	GuildNameCache = {}

	--print("MisspelledForever: Friends names and guild members loading...")

	--First check your friends list
	numFriends = Compat.GetNumFriends()
	if numFriends > 0 then
		for i = 1, numFriends do
			friendName = Compat.GetFriendName(i)
			if friendName ~= nil and #friendName > 0 then
				FriendNameCache[self:NormalizeName(friendName)] = true
				if WordDict:Contains(friendName) == false then
					self:AddWordToDictionary(friendName, false)
				end
			end
		end
	end

	-- Guild members are valid words.
	local numTotalInGuild, guildMemberName
	if Compat.GetNumGuildMembers() ~= 0 then
		numTotalInGuild = Compat.GetNumGuildMembers()
		if ( numTotalInGuild > 0 ) then
			for i=1, numTotalInGuild do
				guildMemberName = Compat.GetGuildRosterName(i)
				if guildMemberName ~= nil then
					if #guildMemberName ~= 0 then
						GuildNameCache[self:NormalizeName(guildMemberName)] = true
						if WordDict:Contains(guildMemberName) == false then
							self:AddWordToDictionary(guildMemberName, false)
						end
					end
				end
			end
		end
		--print("MisspelledForever: Guild Members Loaded")
		MisspelledForever:UnregisterEvent("GUILD_ROSTER_UPDATE")
	end
end

-------------------------------------------------------------------------
-- End: Load Guild and Friend Roster Routine
-------------------------------------------------------------------------

--[[ Interface Options Window ]]--
function MisspelledForever:BuildAceOptions()
	local dictValues = {}
	for _, dict in ipairs(DICTIONARIES) do
		dictValues[dict.locale] = dict.label
	end

	local chatArgs = {}
	for order, chatType in ipairs(CHAT_TYPES) do
		chatArgs[chatType.key] = {
			type = "toggle",
			name = chatType.label,
			order = order,
			get = function() return self:IsChatTypeEnabled(chatType.key) end,
			set = function(_, value) self:SetChatTypeEnabled(chatType.key, value) end,
		}
	end

	return {
		type = "group",
		name = "MisspelledForever",
		args = {
			general = {
				type = "group",
				name = "General",
				inline = true,
				order = 1,
				args = {
					autoSelect = {
						type = "toggle",
						name = L["Auto Select Dictionary to Load"],
						order = 1,
						get = function() return EnsureDB().AutoSelectDictionary end,
						set = function(_, value) EnsureDB().AutoSelectDictionary = value and true or false end,
					},
					dictionary = {
						type = "select",
						name = "Dictionary",
						order = 2,
						values = dictValues,
						disabled = function() return EnsureDB().AutoSelectDictionary end,
						get = function() return EnsureDB().LoadDictionary end,
						set = function(_, value) EnsureDB().LoadDictionary = value end,
					},
					highlight = {
						type = "color",
						name = "Highlight color",
						order = 3,
						hasAlpha = true,
						get = function() return HexToRGBA(EnsureDB().HighlightColor) end,
						set = function(_, r, g, b, a) self:SetHighlightColor(RGBAtoHex(r, g, b, a)) end,
					},
					cacheMax = {
						type = "range",
						name = "Cache limit",
						order = 4,
						min = 100,
						max = 30000,
						step = 100,
						get = function() return EnsureDB().CacheMax end,
						set = function(_, value) self:SetCacheMax(value) end,
					},
				},
			},
			chatTypes = {
				type = "group",
				name = "Chat Types",
				inline = true,
				order = 2,
				args = chatArgs,
			},
			userDict = {
				type = "group",
				name = "User Dictionary",
				inline = true,
				order = 3,
				args = {
					edit = {
						type = "execute",
						name = L["Edit User Dictionary..."],
						order = 1,
						func = function() self:EditUserDict() end,
					},
					import = {
						type = "execute",
						name = "Import",
						order = 2,
						func = function() self:OpenUserDictTransfer("import") end,
					},
					export = {
						type = "execute",
						name = "Export",
						order = 3,
						func = function() self:OpenUserDictTransfer("export") end,
					},
				},
			},
		},
	}
end

function MisspelledForever:RegisterAceConfigOptions()
	local AceConfig = LibStub("AceConfig-3.0", true)
	local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
	if not AceConfig or not AceConfigDialog then return false end

	AceConfig:RegisterOptionsTable(ADDON_NAME, function() return self:BuildAceOptions() end)
	self.OptionsCategory = AceConfigDialog:AddToBlizOptions(ADDON_NAME, "MisspelledForever")
	self.UsesAceConfig = true
	return true
end

local function SetCheckButtonText(button, text)
	local label = button.Text or button.text
	if not label then
		label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		label:SetPoint("LEFT", button, "RIGHT", 4, 0)
		button.Text = label
	end
	label:SetText(text)
end

function MisspelledForever:RefreshFallbackOptions()
	if not self.FallbackOptions then return end
	local db = EnsureDB()
	self.FallbackOptions.autoSelect:SetChecked(db.AutoSelectDictionary)
	for locale, button in pairs(self.FallbackOptions.dictionaryButtons) do
		button:SetChecked(db.LoadDictionary == locale)
		if db.AutoSelectDictionary then button:Disable() else button:Enable() end
	end
	for chatType, button in pairs(self.FallbackOptions.chatButtons) do
		button:SetChecked(self:IsChatTypeEnabled(chatType))
	end
	self.FallbackOptions.colorBox:SetText(db.HighlightColor)
	self.FallbackOptions.cacheBox:SetText(tostring(db.CacheMax))
end

function MisspelledForever:CreateFallbackOptions()
	local cfgFrame = CreateFrame("Frame", nil, UIParent)
	cfgFrame.name = "MisspelledForever"
	self.OptionsFrame = cfgFrame
	self.FallbackOptions = { dictionaryButtons = {}, chatButtons = {} }

	local header = cfgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	header:SetPoint("TOPLEFT", 15, -15)
	header:SetText("MisspelledForever " .. self.Version)

	local reloadTip = cfgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	reloadTip:SetPoint("TOPLEFT", 20, -252)
	reloadTip:SetText(L["Note: reload the game UI to load a different selected dictionary"])

	local function newCheck(label, x, y, checked, onClick)
		local button = CreateFrame("CheckButton", nil, cfgFrame, "InterfaceOptionsCheckButtonTemplate")
		button:SetPoint("TOPLEFT", x, y)
		SetCheckButtonText(button, label)
		button:SetChecked(checked)
		button:SetScript("OnClick", function(control)
			PlaySound(control:GetChecked() and 856 or 857)
			onClick(control)
		end)
		return button
	end

	self.FallbackOptions.autoSelect = newCheck(L["Auto Select Dictionary to Load"], 20, -40, EnsureDB().AutoSelectDictionary, function(control)
		EnsureDB().AutoSelectDictionary = control:GetChecked() and true or false
		self:RefreshFallbackOptions()
	end)

	for index, dict in ipairs(DICTIONARIES) do
		local button = newCheck(dict.label, 40, -40 - (index * 24), EnsureDB().LoadDictionary == dict.locale, function(control)
			if control:GetChecked() then
				EnsureDB().LoadDictionary = dict.locale
			end
			self:RefreshFallbackOptions()
		end)
		self.FallbackOptions.dictionaryButtons[dict.locale] = button
	end

	local colorLabel = cfgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	colorLabel:SetPoint("TOPLEFT", 260, -40)
	colorLabel:SetText("Highlight ARGB hex")
	local colorBox = CreateFrame("EditBox", nil, cfgFrame, "InputBoxTemplate")
	colorBox:SetPoint("TOPLEFT", 260, -62)
	colorBox:SetSize(110, 24)
	colorBox:SetAutoFocus(false)
	self.FallbackOptions.colorBox = colorBox
	local colorButton = CreateFrame("Button", nil, cfgFrame, "UIPanelButtonTemplate")
	colorButton:SetPoint("LEFT", colorBox, "RIGHT", 10, 0)
	colorButton:SetSize(60, 24)
	colorButton:SetText("Apply")
	colorButton:SetScript("OnClick", function()
		self:SetHighlightColor(colorBox:GetText())
		self:RefreshFallbackOptions()
	end)

	local cacheLabel = cfgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	cacheLabel:SetPoint("TOPLEFT", 260, -96)
	cacheLabel:SetText("Cache limit")
	local cacheBox = CreateFrame("EditBox", nil, cfgFrame, "InputBoxTemplate")
	cacheBox:SetPoint("TOPLEFT", 260, -118)
	cacheBox:SetSize(110, 24)
	cacheBox:SetAutoFocus(false)
	self.FallbackOptions.cacheBox = cacheBox
	local cacheButton = CreateFrame("Button", nil, cfgFrame, "UIPanelButtonTemplate")
	cacheButton:SetPoint("LEFT", cacheBox, "RIGHT", 10, 0)
	cacheButton:SetSize(60, 24)
	cacheButton:SetText("Apply")
	cacheButton:SetScript("OnClick", function()
		self:SetCacheMax(cacheBox:GetText())
		self:RefreshFallbackOptions()
	end)

	for index, chatType in ipairs(CHAT_TYPES) do
		local column = index > 6 and 1 or 0
		local row = ((index - 1) % 6)
		local button = newCheck(chatType.label, 260 + (column * 150), -158 - (row * 24), self:IsChatTypeEnabled(chatType.key), function(control)
			self:SetChatTypeEnabled(chatType.key, control:GetChecked())
		end)
		self.FallbackOptions.chatButtons[chatType.key] = button
	end

	local userDictButton = CreateFrame("Button", nil, cfgFrame, "UIPanelButtonTemplate")
	userDictButton:SetPoint("TOPLEFT", 20, -287)
	userDictButton:SetSize(200, 24)
	userDictButton:SetText(L["Edit User Dictionary..."])
	userDictButton:SetScript("OnClick", function() self:EditUserDict() end)

	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(cfgFrame)
	elseif Settings then
		local category = Settings.RegisterCanvasLayoutCategory(cfgFrame, cfgFrame.name)
		self.OptionsCategory = category
		Settings.RegisterAddOnCategory(category)
	end

	self:RefreshFallbackOptions()
end

function MisspelledForever:CreateInterfaceOptions()
	if not self:RegisterAceConfigOptions() then
		self:CreateFallbackOptions()
	end
end

function MisspelledForever:OpenOptions()
	local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
	if self.UsesAceConfig and AceConfigDialog then
		AceConfigDialog:Open(ADDON_NAME)
	elseif Settings and self.OptionsCategory then
		local categoryID = self.OptionsCategory.GetID and self.OptionsCategory:GetID() or self.OptionsCategory.ID or self.OptionsCategory.name
		Settings.OpenToCategory(categoryID)
	elseif InterfaceOptionsFrame_OpenToCategory and self.OptionsFrame then
		InterfaceOptionsFrame_OpenToCategory(self.OptionsFrame)
		InterfaceOptionsFrame_OpenToCategory(self.OptionsFrame)
	else
		self:print("Open Interface > AddOns > MisspelledForever")
	end
end

function MisspelledForever:PrintStatus()
	local db = EnsureDB()
	local enabledTypes = {}
	for _, chatType in ipairs(CHAT_TYPES) do
		if self:IsChatTypeEnabled(chatType.key) then
			table_insert(enabledTypes, chatType.key)
		end
	end
	self:print("MisspelledForever " .. self.Version)
	self:print("Dictionary: " .. self:GetSelectedDictionary() .. " -> " .. tostring(WordDict.locale or "not loaded"))
	self:print("Dictionary module: " .. tostring(WordDict.loadedDictionaryAddon or "unknown"))
	if WordDict.dictionaryLoadFallbackReason then
		self:print("Dictionary fallback: " .. tostring(WordDict.dictionaryLoadFallbackReason))
	end
	self:print("Highlight: " .. db.HighlightColor)
	self:print("User words: " .. CountKeys(db.UserDict))
	self:print("Cache: " .. WordCacheCount .. "/" .. WordCacheCountMax)
	self:print("Enabled chat: " .. table.concat(enabledTypes, ", "))
end

function MisspelledForever:PrintHelp()
	self:print("MisspelledForever commands:")
	self:print("/msf options")
	self:print("/msf userdict")
	self:print("/msf import <words>")
	self:print("/msf export")
	self:print("/msf reload")
	self:print("/msf status")
	self:print("/msf color <ARGB or RGB hex>")
	self:print("/msf enable <chatType> / /msf disable <chatType>")
end

function MisspelledForever:HandleSlash(msg)
	local command, rest = string_match(msg or "", "^%s*(%S*)%s*(.-)%s*$")
	command = string_lower(command or "")
	rest = rest or ""

	if command == "" or command == "options" or command == "config" then
		self:OpenOptions()
	elseif command == "userdict" or command == "dict" then
		self:EditUserDict()
	elseif command == "import" then
		if #rest > 0 then
			self:print("Imported " .. self:ImportUserDict(rest) .. " user dictionary word(s).")
		else
			self:OpenUserDictTransfer("import")
		end
	elseif command == "export" then
		self:OpenUserDictTransfer("export")
	elseif command == "reload" then
		self:print("Reloading UI to apply dictionary load changes.")
		if ReloadUI then ReloadUI() end
	elseif command == "status" then
		self:PrintStatus()
	elseif command == "cache" and rest == "clear" then
		self:ClearWordCache()
		self:print("Word cache cleared.")
	elseif command == "color" and #rest > 0 then
		self:SetHighlightColor(rest)
		self:print("Highlight color set to " .. EnsureDB().HighlightColor)
	elseif command == "enable" or command == "disable" then
		local chatType = string_upper(rest)
		if self:SetChatTypeEnabled(chatType, command == "enable") then
			self:print(chatType .. " spell checking " .. (command == "enable" and "enabled." or "disabled."))
		else
			self:PrintHelp()
		end
	elseif command == "help" then
		self:PrintHelp()
	else
		self:PrintHelp()
	end
end

SLASH_MISSPELLEDFOREVER1 = "/misspelledforever"
SLASH_MISSPELLEDFOREVER2 = "/msf"
SlashCmdList["MISSPELLEDFOREVER"] = function(msg)
	MisspelledForever:HandleSlash(msg)
end


-------------------------------------------------------------------------
--
-- Utility Routines
--
-------------------------------------------------------------------------

--Split a string, at patt delimiter, into a table
function MisspelledForever:split(str, patt)
	local vals = {}
	local valindex = 0
	local word = ""
	-- need to add a trailing separator to catch the last value.
	str = str .. patt
	for i = 1, string_len(str) do
		local cha = string_sub(str, i, i)
		if cha ~= patt then
			word = word .. cha
		else
			if word ~= nil then
				vals[valindex] = word
				valindex = valindex + 1
				word = ""
			else
				-- in case we get a line with no data.
				break
			end
		end

	end
	return vals
end

function MisspelledForever:tprint (t, indent, done)
  -- in case we run it standalone outside of the Wow client Lua env
  local Note = Note or print
  --local Tell = Tell or io.write

  -- show strings differently to distinguish them from numbers
  local function show (val)
    if type (val) == "string" then
      return '"' .. val .. '"'
    else
      return tostring(val)
    end -- if
  end -- show
  
  -- entry point here
  done = done or {}
  indent = indent or 0
  for key, value in pairs (t) do
    print(string_rep(" ", indent)) -- indent it
    if type (value) == "table" and not done [value] then
      done [value] = true
      Note (show (key), ":");
      MisspelledForever:tprint(value, indent + 2, done)
    else
      print(show (key), "=")
      print (show (value))
    end
  end
end

function MisspelledForever:print(...)
	local frame = SELECTED_DOCK_FRAME or DEFAULT_CHAT_FRAME
	if frame and frame.AddMessage then
		frame:AddMessage(...)
	end
end

--Check your friends list to see if the string: name is on the friends list.
function MisspelledForever:IsFriend(name)
	return FriendNameCache[self:NormalizeName(name)] == true
end

--check the guild roster to see if the string: name, is a guild member.
function MisspelledForever:IsGuildMember(name)
	return GuildNameCache[self:NormalizeName(name)] == true
end
-------------------------------------------------------------------------
-- End: Utility Routines
-------------------------------------------------------------------------


--[[
--testing
require("bit")
require("WordDict")
--~ require("Dict\\Dic_en_US")
--~ MisspelledForever_DB = {}
--~ WordDict:Init()
--~ ChatFrameEditBox = {}
--~ function ChatFrameEditBox:GetText()
--~ 	return "Leatherworking"
--~ end
s = "Test |cffff91c8A|cffxxxxxxBSecondWord|r|r"
s2 = string.gsub(s, SPELLED_WRONG_HIGHLIGHT .. "(.-)|r", function(x) return x end)
print(s2)
---]]
