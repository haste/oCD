--[[
-- The code is largly based on GTB: http://shadowed-wow.googlecode.com/svn/trunk/GTB/
]]

local fmod, floor, abs, upper, format = math.fmod, math.floor, math.abs, string.upper, string.format

local framePool = {}
local groups = {}

local L = {
	["BAD_ARGUMENT"] = "bad argument #%d for '%s' (%s expected, got %s)",
	["MUST_CALL"] = "You must call '%s' from a registered GTB object.",
	["GROUP_EXISTS"] = "The group '%s' already exists.",
}

local backdrop = {
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground", tile = true, tileSize = 16,
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8,
	insets = {left = 2, right = 2, top = 2, bottom = 2},
}

local BarOnUpdate = function()
	return function(self, elapsed)
		local duration = self.duration - elapsed
		if(duration <= 0) then
			self.group:UnregisterBar(self.id)
			return
		end

		local min, sec = floor(duration / 60), fmod(duration, 60)
		if(min > 0) then
			self.text:SetFormattedText("%d:%02d", min, sec)
		elseif(sec < 10) then
			self.text:SetFormattedText("%.1f", sec)
		else
			self.text:SetFormattedText("%d", sec)
		end

		local sb = self.sb
		local percent = duration / self.max
		-- Color gradient towards red
		if(self.gradients) then
			-- finalColor + (currentColor - finalColor) * percentLeft
			sb:SetStatusBarColor(1.0 + (self.r - 1.0) * percent, self.g * percent, self.b * percent)
		end

		self.duration = duration
		sb:SetValue(duration)
	end
end

local function getFrame()
	-- Check for an unused bar
	if( #(framePool) > 0 ) then
		return table.remove(framePool, 1)
	end

	local frame = CreateFrame"Frame"
	frame:Hide()
	frame:SetParent(UIParent)
	frame:SetBackdrop(backdrop)
	frame:SetBackdropColor(0, 0, 0)
	frame:SetBackdropBorderColor(0, 0, 0)

	local cd = CreateFrame"Cooldown"
	cd.noomnicc = true
	cd:SetParent(frame)
	cd:SetPoint("RIGHT", -2, 0)

	local font, size = GameFontNormalSmall:GetFont()
	local text = cd:CreateFontString()
	text:SetFont(font, size, 'OUTLINE')
	text:SetDrawLayer"OVERLAY"
	text:SetTextColor(1, 1, 1)
	text:SetPoint("BOTTOM", cd, 1, 1)

	local icon = cd:CreateTexture()
	icon:SetDrawLayer"BACKGROUND"
	icon:SetTexCoord(.07, .93, .07, .93)
	icon:SetAllPoints(cd)

	local sb = CreateFrame"StatusBar"
	sb:SetParent(frame)
	sb:SetPoint('LEFT', 2, 0)
	sb:SetPoint('RIGHT', cd, 'LEFT')

	frame:SetScript('OnUpdate', BarOnUpdate())

	frame.update = update
	frame.cd = cd
	frame.text = text
	frame.sb = sb
	frame.icon = icon

	return frame
end

local function releaseFrame(frame)
	-- Stop updates
	frame:Hide()

	-- And now read to the frame pool
	table.insert(framePool, frame)
end

-- Reposition the group
local function sortBars(a, b)
	return a.duration > b.duration
end

local function getRelativePointAnchor(point)
	point = upper(point)
	if (point == "TOP") then
		return "BOTTOM", 0, -1
	elseif (point == "BOTTOM") then
		return "TOP", 0, 1
	elseif (point == "LEFT") then
		return "RIGHT", 1, 0
	elseif (point == "RIGHT") then
		return "LEFT", -1, 0
	elseif (point == "TOPLEFT") then
		return "BOTTOMRIGHT", 1, -1
	elseif (point == "TOPRIGHT") then
		return "BOTTOMLEFT", -1, -1
	elseif (point == "BOTTOMLEFT") then
		return "TOPRIGHT", 1, 1
	elseif (point == "BOTTOMRIGHT") then
		return "TOPLEFT", -1, 1
	else
		return "CENTER", 0, 0
	end
end

local function repositionFrames(group)
	local bars = #group.usedBars
	-- if we have less bars, we don't need to re-arrange anything.
	if(bars < group.lastUpdate) then return end

	table.sort(group.usedBars, sortBars)
	local frame = group.frame
	local point = frame.point
	local relativePoint, xOffsetMult, yOffsetMult = getRelativePointAnchor(point)
	local xMultiplier, yMultiplier = abs(xOffsetMult), abs(yOffsetMult)
	local xOffset = frame.xOffset
	local yOffset = frame.yOffset
	local columnSpacing = frame.columnSpacing

	local columnMax = frame.columnMax
	local numColumns
	if ( columnMax and bars > columnMax ) then
		numColumns = ceil(bars / columnMax)
	else
		columnMax = bars
		numColumns = 1
	end

	local columnAnchorPoint, columnRelPoint, colxMulti, colyMulti
	if(numColumns > 1) then
		columnAnchorPoint = frame.columnAnchorPoint
		columnRelPoint, colxMulti, colyMulti = getRelativePointAnchor(columnAnchorPoint)
	end

	local columnNum = 1
	local columnCount = 0
	local currentAnchor = group
	for i = 1, bars do
		columnCount = columnCount + 1
		if ( columnCount > columnMax ) then
			columnCount = 1
			columnNum = columnNum + 1
		end

		local bar = group.usedBars[i]
		bar:ClearAllPoints()
		if ( i == 1 ) then
			bar:SetPoint(point, currentAnchor, point, 0, 0)
			if ( columnAnchorPoint ) then
				bar:SetPoint(columnAnchorPoint, currentAnchor, columnAnchorPoint, 0, 0)
			end
		elseif ( columnCount == 1 ) then
			local columnAnchor = group.usedBars[(i - columnMax)]
			bar:SetPoint(columnAnchorPoint, columnAnchor, columnRelPoint, colxMulti * columnSpacing, colyMulti * columnSpacing)
		else
			bar:SetPoint(point, currentAnchor, relativePoint, xMultiplier * xOffset, yMultiplier * yOffset)
		end

		currentAnchor = bar
	end

	group.lastUpdate = bars
end

local display = {
	-- Group related:
	RegisterGroup = function(self, name, ...)
		assert(3, not groups[name], string.format(L["GROUP_EXISTS"], name))
		local obj = CreateFrame"Frame"
		obj:SetParent(UIParen)

		obj.name = name
		obj.bars = {}
		obj.usedBars = {}

		-- Register
		groups[name] = obj

		-- Set defaults
		obj:SetHeight(1)
		obj:SetWidth(1)

		obj.RegisterBar = self.RegisterBar
		obj.UnregisterBar = self.UnregisterBar

		if(select("#", ...) > 0) then
			obj:SetPoint(...)
		else
			obj:SetPoint"CENTER"
		end

		return obj
	end,

	-- Bar related:
	RegisterBar = function(group, id, startTime, seconds, icon, r, g, b)
		assert(3, group.name and groups[group.name], string.format(L["MUST_CALL"], "RegisterBar"))

		-- Already exists, remove the old one quickly
		if( group.bars[id] ) then
			group:UnregisterBar(id)
		end

		-- Retrieve a frame thats either recycled, or a newly created one
		local frame = getFrame()

		-- So we can do sorting and positioning
		table.insert(group.usedBars, frame)

		local fSize = group.frame.size
		local sbSize, sbPoint = group.statusbar.size, group.statusbar.point
		frame:SetWidth(fSize + sbSize + 6)
		frame:SetHeight(fSize + 3)

		frame.cd:SetWidth(fSize)
		frame.cd:SetHeight(fSize)

		local sb = frame.sb
		sb:SetHeight(fSize)
		sb:SetWidth(sbSize)
		sb:SetOrientation(group.statusbar.orientation)

		-- Set info the bar needs to know
		frame.r = r or group.baseColor.r
		frame.g = g or group.baseColor.g
		frame.b = b or group.baseColor.b
		frame.group = group

		local duration = startTime - GetTime() + seconds
		frame.duration = duration
		frame.max = seconds

		frame.gradients = group.statusbar.gradients
		frame.id = id

		-- Reset last update.
		group.lastUpdate = 0
		-- Reposition this group
		repositionFrames(group)

		-- Start it up
		frame.icon:SetTexture(icon)
		sb:SetStatusBarTexture(group.statusbar.texture)
		sb:SetStatusBarColor(frame.r, frame.g, frame.b)
		sb:SetMinMaxValues(0, seconds)
		sb:SetValue(duration)
		frame.cd:SetCooldown(startTime, seconds)
		frame:Show()

		-- Register it
		group.bars[id] = frame
	end,

	UnregisterBar = function(group, id)
		assert(3, group.name and groups[group.name], string.format(L["MUST_CALL"], "UnregisterBar"))

		-- Remove the old entry
		if( group.bars[id] ) then
			-- Remove from list of used bars
			for i=#(group.usedBars), 1, -1 do
				if( group.usedBars[i].id == id ) then
					table.remove(group.usedBars, i)
					break
				end
			end

			releaseFrame(group.bars[id])
			repositionFrames(group)
			group.bars[id] = nil
			return true
		end

		return
	end,
}

oCD.display = display
