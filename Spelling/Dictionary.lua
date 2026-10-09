local _, ns = ...
local Dictionary = {}
ns.Dictionary = Dictionary
local U = ns.Unicode
local normalize = U.Lower

-- These methods operate on the engine's active dictionary state.
-- Packed source data stays available so languages can change without a reload.
-- Sorted word chunks store a byte-prefix length followed by the new suffix.
-- Prefix boundaries are always complete UTF-8 characters.
local function packWords(pack, visit)
	for _, chunk in ipairs(pack.chunks) do
		if pack.packed then
			local previous = ""
			for line in chunk:gmatch("[^\r\n]+") do
				local word = previous:sub(1, tonumber(line:sub(1, 2), 16)) .. line:sub(3)
				visit(word); previous = word
			end
		else
			for word in chunk:gmatch("%S+") do visit(word) end
		end
	end
end

function Dictionary:Initialize(personal, languages)
	self.words, self.byLength, self.common, self.wow, self.names = {}, {}, {}, {}, {}
	self.personal = personal or {}
	self.languageSignature = nil
	self:SetLanguages(languages)
	local rank = 0
	for word in ns.CommonWords:gmatch("%S+") do
		rank = rank + 1
		self.common[normalize(word)] = rank
	end
	for word in ns.WowWords:gmatch("%S+") do self.wow[normalize(word)] = true end
end

function Dictionary:SetLanguages(languages)
	languages = languages or { enUS = true }
	local signature, selected = {}, {}
	for _, entry in ipairs(ns.Languages) do
		if languages[entry[1]] and #signature < ns.MaxLanguages then
			signature[#signature + 1] = entry[1]; selected[entry[1]] = true
		end
	end
	if #signature == 0 then signature[1], selected.enUS = "enUS", true end
	languages = selected
	signature = table.concat(signature, ",")
	if self.languageSignature == signature then return end
	self.languageSignature = signature
	self.english = languages.enUS or languages.enGB
	self.words, self.byLength, self.elisionPacks = {}, {}, {}
	local loaded = {}
	for _, entry in ipairs(ns.Languages) do
		local pack = ns.LanguagePacks[entry[1]]
		if languages[entry[1]] and pack and not loaded[pack] then
			loaded[pack] = true
			local blocked = {}
			for _, chunk in ipairs(pack.blocked) do
				for word in chunk:gmatch("%S+") do blocked[word] = true end
			end
			packWords(pack, function(word)
				if self.words[word] == nil then
					local length = U.Length(word)
					local bucket = self.byLength[length]
					if not bucket then bucket = {}; self.byLength[length] = bucket end
					bucket[#bucket + 1] = word
				end
				self.words[word] = self.words[word] or not blocked[word]
			end)
		end
	end
	-- Elisions share a stem plus a compact set of permitted prefixes. This
	-- avoids expanding millions of l'/d'/all' variants into the active index.
	local indexed = {}
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for pack in pairs(loaded) do
		if pack.elisions and #pack.elisions > 0 then
			local data = { prefixes = {}, forms = {} }
			for i, prefix in ipairs(pack.prefixes) do
				data.prefixes[prefix] = pack.elisionEncoding == "indices" and ("," .. i .. ",") or alphabet:sub(i, i)
			end
			for _, chunk in ipairs(pack.elisions) do
				local previous = ""
				for word, codes in chunk:gmatch("(%S+) (%S+)") do
					if pack.packed then
						word = previous:sub(1, tonumber(word:sub(1, 2), 16)) .. word:sub(3)
						previous = word
						codes = pack.elisionFlags[tonumber(codes)]
					end
					data.forms[word] = codes
					if self.words[word] == nil and not indexed[word] then
						indexed[word] = true
						local length = U.Length(word)
						self.byLength[length] = self.byLength[length] or {}
						local bucket = self.byLength[length]; bucket[#bucket + 1] = word
					end
				end
			end
			self.elisionPacks[#self.elisionPacks + 1] = data
		end
	end
	-- Sorting the existing arrays allows prefix pruning without a second word index.
	for _, bucket in pairs(self.byLength) do table.sort(bucket) end
	self.searchSorted = true
end

function Dictionary:Elision(prefix, stem, suggest)
	for _, pack in ipairs(self.elisionPacks or {}) do
		local code, flags = pack.prefixes[prefix], pack.forms[stem]
		if code and flags then
			local accepted, suggested = flags:match("^(.-):(.*)$")
			if (suggest and suggested or accepted):find(code, 1, true) then return true end
		end
	end
	return false
end

function Dictionary:Contains(word, includeWow)
	word = normalize(word)
	local prefix, stem = word:match("^([^']+)'(.+)$")
	return self.words[word] ~= nil or self.personal[word] or self.names[word]
		or (includeWow and self.wow[word]) or (prefix and self:Elision(prefix, stem, false)) or false
end

-- Traverse a virtual prefix tree over sorted arrays. Rows are shared by words
-- with the same prefix; whole ranges are skipped once no completion can fit.
-- This uses the same adjacent-transposition distance as Engine.Distance.
function Dictionary.VisitSimilar(self, chars, closeLimit, wideLimit, visit, yieldWork)
	local length = #chars
	local rows, path = { [0] = {} }, {}
	for j = 0, length do rows[0][j] = j end
	local work = 0
	local function checkpoint()
		work = work + 1
		if yieldWork and work % 64 == 0 then yieldWork() end
	end
	local function walk(bucket, first, last, depth, offset, size)
		local row = rows[depth]
		if not row then
			row = {}; rows[depth] = row
			for j = 0, length do row[j] = closeLimit + 1 end
		end
		local from, to = math.max(1, depth - closeLimit), math.min(length, depth + closeLimit)
		local previous, older = rows[depth - 1], rows[depth - 2]
		local k = first
		while k <= last do
			local lead = bucket[k]:byte(offset)
			local bytes = lead < 128 and 1 or (lead < 224 and 2 or (lead < 240 and 3 or 4))
			local char = bucket[k]:sub(offset, offset + bytes - 1)
			local nextOffset = offset + bytes
			local edge = bucket[k]:sub(1, nextOffset - 1)
			-- Find the end of this shared prefix without visiting its words.
			local low, high = k + 1, last + 1
			while low < high do
				local mid = math.floor((low + high) / 2)
				if bucket[mid]:sub(1, nextOffset - 1) == edge then low = mid + 1 else high = mid end
			end
			local branchEnd = low - 1
			row[0] = depth
			local best = depth + math.abs(length - size + depth)
			for j = from, to do
				local value = previous[j] + 1
				local other = row[j - 1] + 1; if other < value then value = other end
				other = previous[j - 1] + (char == chars[j] and 0 or 1)
				if other < value then value = other end
				if depth > 1 and j > 1 and char == chars[j - 1] and path[depth - 1] == chars[j] then
					other = older[j - 2] + 1; if other < value then value = other end
				end
				row[j] = value
				-- Include the unavoidable remaining length difference in the bound.
				local delta = length - j - size + depth
				local bound = value + (delta < 0 and -delta or delta)
				if bound < best then best = bound end
			end
			checkpoint()
			if best <= closeLimit then
				if depth == size then
					if row[length] <= closeLimit then visit(bucket[k], row[length]) end
				else
					path[depth] = char
					walk(bucket, k, branchEnd, depth + 1, nextOffset, size)
				end
			end
			k = branchEnd + 1
		end
	end
	for size = math.max(1, length - closeLimit), length + closeLimit do
		local bucket = self.byLength[size]
		if bucket then walk(bucket, 1, #bucket, 1, 1, size) end
	end
	if wideLimit <= closeLimit then return end
	-- Wider matches require both endpoints. Only inspect the matching first-
	-- letter range, and reject other endings before calculating any distance.
	local firstChar, lastChar = chars[1], chars[length]
	for size = math.max(1, length - wideLimit), length + wideLimit do
		local bucket = self.byLength[size] or {}
		local low, high = 1, #bucket + 1
		while low < high do
			local mid = math.floor((low + high) / 2)
			if bucket[mid]:sub(1, #firstChar) < firstChar then low = mid + 1 else high = mid end
		end
		for i = low, #bucket do
			local candidate = bucket[i]
			if candidate:sub(1, #firstChar) ~= firstChar then break end
			if candidate:sub(-#lastChar) == lastChar then visit(candidate) end
			checkpoint()
		end
	end
end
