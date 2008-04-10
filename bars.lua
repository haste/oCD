--[[
-- The code is largly based on GTB: http://shadowed-wow.googlecode.com/svn/trunk/GTB/
]]

local framePool = {}
groups = {}

local L = {
	["BAD_ARGUMENT"] = "bad argument #%d for '%s' (%s expected, got %s)",
	["MUST_CALL"] = "You must call '%s' from a registered GTB object.",
	["GROUP_EXISTS"] = "The group '%s' already exists.",
}

local function getFrame()
	-- Check for an unused bar
	if( #(framePool) > 0 ) then
		return table.remove(framePool, 1)
	end

	local frame = CreateFrame"Frame"
	frame:Hide()
	frame:SetParent(UIParent)
	frame:SetBackdrop{
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16,
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8,
		insets = {left = 2, right = 2, top = 2, bottom = 2},
	}
	frame:SetBackdropColor(0, 0, 0)
	frame:SetBackdropBorderColor(0, 0, 0)
	frame:SetScript("OnUpdate", OnUpdate)

	local cd = CreateFrame"Cooldown"
	cd:SetParent(frame)

	local font, size = GameFontNormal:GetFont()
	local text = cd:CreateFontString()
	text:SetDrawLayer"OVERLAY"
	text:SetFont(font, size, "OUTLINE")
	text:SetTextColor(1, 1, 1)
	text:SetPoint("BOTTOM", frame, 1, -2)

	local icon = cd:CreateTexture()
	icon:SetDrawLayer"BACKGROUND"
	icon:SetTexCoord(.07, .93, .07, .93)
	icon:ClearAllPoints()
	icon:SetAllPoints(cd)

	local sb = CreateFrame"StatusBar"
	sb:SetParent(frame)
	sb:SetMinMaxValues(0, 1)

	frame.update = update
	frame.cd = cd
	frame.text = text
	frame.sb = sb
	frame.icon = icon

	return frame
end

local function releaseFrame(frame)
	-- Stop updates
	frame:SetScript("OnUpdate", nil)
	frame:Hide()

	-- And now readd to the frame pool
	table.insert(framePool, frame)
end

-- OnUpdate for a bar
local function OnUpdate(self)
	local time = GetTime()
	-- Check if times ran out and that we need to start fading it out
	self.secondsLeft = self.secondsLeft - (time - self.lastUpdate)
	self.lastUpdate = time
	if( self.secondsLeft <= 0 ) then
		self.sb:SetValue(0)
		self.group:UnregisterBar(self.id)
		return
	end

	-- Timer text, need to see if this can be optimized a bit later
	local hour = floor(self.secondsLeft / 3600)
	local minutes = floor((self.secondsLeft - (hour * 3600)) / 60)
	local seconds = self.secondsLeft - ((hour * 3600) + (minutes * 60))

	if( hour > 0 ) then
		self.text:SetFormattedText("%d:%02d", hour, minute)
	elseif( minutes > 0 ) then
		self.text:SetFormattedText("%d:%02d", minutes, floor(seconds))
	elseif( seconds < 10 ) then
		self.text:SetFormattedText("%.1f", seconds)
	else
		self.text:SetFormattedText("%.0f", floor(seconds))
	end

	local percent = self.secondsLeft / self.startSeconds
	-- Color gradient towards red
	if( self.gradients ) then
		-- finalColor + (currentColor - finalColor) * percentLeft
		self.sb:SetStatusBarColor(1.0 + (self.r - 1.0) * percent, self.g * percent, self.b * percent)
	end

	-- Now update the actual displayed bar
	if(self.fill) then
		self.sb:SetValue(1-percent)
	else
		self.sb:SetValue(percent)
	end
end

-- Reposition the group
local function sortBars(a, b)
	return a.endTime > b.endTime
end

local function repositionFrames(group)
	table.sort(group.usedBars, sortBars)

	local limit = 1
	local row = 1
	for i, bar in ipairs(group.usedBars) do
		if(i == 1) then
			bar:ClearAllPoints()
			bar:SetPoint("TOPLEFT", group, "BOTTOMLEFT")
		else
			bar:ClearAllPoints()
			bar:SetPoint("LEFT", group.usedBars[i-1], "RIGHT")

			local r = math.fmod(i - 1, limit)
			if(r == 0) then
				bar:ClearAllPoints()
				bar:SetPoint("TOPLEFT", group.usedBars[row], "BOTTOMLEFT", 0, -3)
				row = i
			end
		end
	end
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

		-- Grab basic info about the font
		local path, size, style = GameFontHighlight:GetFont()
		size = group.fontSize

		local width, height, point = group.width, group.height, group.point
		local mod = (point == "LEFT" and 1) or -1
		frame:SetWidth(width)
		frame:SetHeight(height)

		frame.cd:ClearAllPoints()
		frame.cd:SetPoint(point == "LEFT" and "RIGHT" or "LEFT", -3*mod, 0)
		frame.cd:SetPoint("TOP", 0, -3)
		frame.cd:SetPoint("BOTTOM", 0, 3)
		frame.cd:SetPoint(point == "LEFT" and "LEFT" or "RIGHT", (width-height+3)*mod, 0)

		local sb = frame.sb
		sb:SetPoint("TOP", frame, 0, -3)
		sb:SetPoint("BOTTOM", 0, 3)
		sb:SetPoint(point == "LEFT" and "LEFT" or "RIGHT", 3*mod, 0)
		if(point == "LEFT") then
			sb:SetPoint("RIGHT", frame.cd, "LEFT")
		else
			sb:SetPoint("LEFT", frame.cd, "RIGHT")
		end
		sb:SetOrientation(group.orientation)

		-- Set info the bar needs to know
		frame.r = r or group.baseColor.r
		frame.g = g or group.baseColor.g
		frame.b = b or group.baseColor.b
		frame.group = group
		frame.lastUpdate = startTime
		frame.endTime = startTime + seconds
		frame.secondsLeft = seconds
		frame.startSeconds = seconds
		frame.gradients = group.gradients
		frame.fill = group.fill
		frame.id = id

		-- Reposition this group
		repositionFrames(group)

		-- Start it up
		frame.icon:SetTexture(icon)
		frame.sb:SetStatusBarTexture(group.texture)
		frame.sb:SetStatusBarColor(frame.r, frame.g, frame.b)
		frame.cd:SetCooldown(startTime, seconds)
		frame:SetScript("OnUpdate", OnUpdate)
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
