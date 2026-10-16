local _, ns = ...
local UI = ns.UI

-- Native edit-box colors. No overlay measuring, resizing, or update polling.
UI.markers = {}

function UI:RawText(box)
	local marker = self.markers[box]
	return ns.Engine.StripHighlights(box:GetText(), marker and marker.prefixes, box:GetCursorPosition())
end

function UI:IsFormatting(box)
	local marker = self.markers[box]
	-- The game can deliver OnTextChanged after SetText has returned. A
	-- call-stack guard alone then treats our own colors as new user input,
	-- strips them, and schedules another highlight indefinitely.
	return marker and (marker.updating or box:GetText() == marker.expectedText)
end

local function setDisplay(box, marker, text, cursor)
	if box:GetText() == text then return end
	marker.expectedText = text
	marker.updating = true
	box:SetText(text)
	box:SetCursorPosition(cursor)
	marker.updating = false
end

function UI:ClearMarks(box)
	for editBox, marker in pairs(self.markers) do
		if not box or box == editBox then
			local raw, cursor = self:RawText(editBox)
			setDisplay(editBox, marker, raw, cursor)
			marker.issues, marker.ranges = {}, {}
		end
	end
end

-- Compare against the edit box's actual text color, including custom channel colors.
-- Keep the saved preference unchanged; only the displayed highlight can differ.
local alternatives = { {0.2, 0.85, 1}, {1, 0.25, 0.8}, {1, 1, 0.2}, {0.4, 1, 0.3} }
local function highlightColor(box)
	local chosen = ns.db.highlightColor
	if not box.GetTextColor then return chosen end
	local r, g, b = box:GetTextColor()
	if issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b)) then return chosen end
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return chosen end
	local function distance(color)
		return 0.299 * (color[1] - r)^2 + 0.587 * (color[2] - g)^2 + 0.114 * (color[3] - b)^2
	end
	-- A weighted RGB distance below 0.2 is treated as visually too similar.
	if distance(chosen) >= 0.04 then return chosen end
	local best, bestDistance = chosen, 0
	for _, color in ipairs(alternatives) do
		local value = distance(color)
		if value > bestDistance then best, bestDistance = color, value end
	end
	return best
end

function UI:ShowMarks(box, issues)
	local marker = self.markers[box]
	if not marker then
		marker = { prefixes = {}, issues = {}, ranges = {} }
		self.markers[box] = marker
	end
	local raw, cursor = self:RawText(box)
	marker.text, marker.issues, marker.ranges = raw, issues, issues
	local color = highlightColor(box)
	-- The private alpha value distinguishes these tags from ordinary |cff
	-- item-link colors. Visually it is effectively opaque.
	local prefix = string.format("|cfe%02x%02x%02x", math.floor(color[1]*255+0.5),
		math.floor(color[2]*255+0.5), math.floor(color[3]*255+0.5))
	marker.prefixes[prefix] = true
	local result, from, decoratedCursor, extra = {}, 1, cursor, 0
	local maxBytes = box.GetMaxBytes and box:GetMaxBytes() or 0
	for _, issue in ipairs(issues) do
		result[#result+1] = raw:sub(from, issue.first-1)
		local highlighted = ns.db.showHighlights and ns.db.enabled
			and (maxBytes == 0 or #raw + extra + 12 <= maxBytes)
		if highlighted then
			result[#result+1] = prefix .. issue.word .. "|r"
			extra = extra + 12
			if cursor >= issue.first-1 then decoratedCursor = decoratedCursor + 10 end
			if cursor >= issue.last then decoratedCursor = decoratedCursor + 2 end
		else result[#result+1] = issue.word end
		from = issue.last+1
	end
	result[#result+1] = raw:sub(from)
	local decorated = table.concat(result)
	setDisplay(box, marker, decorated, decoratedCursor)
	-- A client may enforce an additional visible/invisible character limit.
	-- Restore the entire original input if display formatting was truncated.
	if box:GetText() ~= decorated then setDisplay(box, marker, raw, cursor) end
end

function UI:IssueAtMouse(box)
	local marker = self.markers[box]
	if not marker then return end
	local raw, cursor = self:RawText(box)
	if marker.text ~= raw then return end
	for _, issue in ipairs(marker.issues) do
		if cursor >= issue.first-1 and cursor <= issue.last then return issue end
	end
end
