local _, ns = ...
local Engine = ns.Engine

function ns.PrintMessage(text)
	DEFAULT_CHAT_FRAME:AddMessage("|cff52c7b8MisspelledForever:|r " .. text)
end

function ns.RegisterCommands()
	SLASH_MISSPELLEDFOREVER1, SLASH_MISSPELLEDFOREVER2 = "/mf", "/misspelledforever"
	SlashCmdList.MISSPELLEDFOREVER = function(message)
		local command, argument = message:match("^%s*(%S*)%s*(.-)%s*$")
		command = command:lower()
		if command == "on" or command == "off" then
			ns.SetOption("enabled", command == "on")
			ns.PrintMessage(command == "on" and "Spelling checks enabled." or "Spelling checks paused.")
		elseif command == "minimap" then
			ns.SetOption("showMinimap", not ns.db.showMinimap)
			ns.PrintMessage(ns.db.showMinimap and "Minimap button shown." or "Minimap button hidden. Use /mf for settings.")
		elseif command == "add" then
			local word = Engine.Normalize(argument)
			local count = 0
			for _ in pairs(ns.db.personalWords) do count = count + 1 end
			if ns.ValidPersonalWord(word) and count < 800 then
				ns.db.personalWords[word] = true; ns.OptionsChanged(); ns.PrintMessage("Learned " .. word .. ".")
			else ns.PrintMessage("Use /mf add <word> (2-28 Latin letters; accents allowed), or edit your personal list in /mf.") end
		elseif command == "help" then
			ns.PrintMessage("/mf settings â€¢ /mf on|off â€¢ /mf minimap â€¢ /mf add <word>. Click an colored word for corrections.")
		elseif command == "debug" then
			ns.Chat:PrintDebug()
		else ns.OpenSettings() end
	end
end
