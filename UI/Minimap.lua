local _, ns = ...
local UI = ns.UI
local ICON, ACCENT = UI.ICON, UI.ACCENT
local BORDER_OFFSET = 7 -- Place the icon's inner edge near the minimap border.

function UI:UpdateMinimap()
	if not self.minimap then return end
	local angle = math.rad(ns.db.minimapAngle)
	local halfWidth, halfHeight = Minimap:GetWidth() / 2, Minimap:GetHeight() / 2
	local x, y = math.cos(angle), math.sin(angle)
	local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
	local round = {
		ROUND = {true, true, true, true}, SQUARE = {false, false, false, false},
		["CORNER-TOPLEFT"] = {false, false, false, true},
		["CORNER-TOPRIGHT"] = {false, false, true, false},
		["CORNER-BOTTOMLEFT"] = {false, true, false, false},
		["CORNER-BOTTOMRIGHT"] = {true, false, false, false},
		["SIDE-LEFT"] = {false, true, false, true},
		["SIDE-RIGHT"] = {true, false, true, false},
		["SIDE-TOP"] = {false, false, true, true},
		["SIDE-BOTTOM"] = {true, true, false, false},
		["TRICORNER-TOPLEFT"] = {false, true, true, true},
		["TRICORNER-TOPRIGHT"] = {true, false, true, true},
		["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
		["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
	}
	local quadrant = 1 + (x < 0 and 1 or 0) + (y > 0 and 2 or 0)
	if not (round[shape] or round.ROUND)[quadrant] then
		local divisor = math.max(math.abs(x), math.abs(y))
		x, y = x / divisor, y / divisor
	end
	self.minimap:ClearAllPoints()
	self.minimap:SetPoint("CENTER", Minimap, "CENTER", x * (halfWidth + BORDER_OFFSET), y * (halfHeight + BORDER_OFFSET))
	self.minimap:SetShown(ns.db.showMinimap)
end

function UI:CreateMinimap()
	local b = CreateFrame("Button", "MisspelledForeverMinimapButton", Minimap)
	b:SetSize(32, 32); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(Minimap:GetFrameLevel() + 10)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp"); b:RegisterForDrag("LeftButton")
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICON); icon:SetSize(22, 22); icon:SetPoint("CENTER")
	local border = b:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(54, 54); border:SetPoint("TOPLEFT")
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	b:SetScript("OnClick", function(_, mouse)
		if mouse == "RightButton" then ns.SetOption("enabled", not ns.db.enabled)
		else ns.OpenSettings() end
	end)
	b:SetScript("OnDragStart", function(self)
		GameTooltip:Hide()
		self:SetScript("OnUpdate", function()
			local cx, cy = Minimap:GetCenter()
			local mx, my = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			ns.db.minimapAngle = math.deg(math.atan2(my / scale - cy, mx / scale - cx))
			UI:UpdateMinimap()
		end)
	end)
	b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("MisspelledForever")
		GameTooltip:AddLine(ns.db.enabled and "Spelling checks enabled" or "Spelling checks paused", unpack(ACCENT))
		GameTooltip:AddLine("Left-click: settings\nRight-click: enable / pause\nDrag: move button", 0.9, 0.9, 0.9)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	self.minimap = b
	Minimap:HookScript("OnSizeChanged", function() UI:UpdateMinimap() end)
	self:UpdateMinimap()
end
