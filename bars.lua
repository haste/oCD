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
	sb:SetPoint("TOP", frame, 0, -3)
	sb:SetPoint("BOTTOM", 0, 3)
	sb:SetPoint("LEFT", 3, 0)
	sb:SetPoint("RIGHT", cd, "LEFT")
	sb:SetOrientation"VERTICAL"
	sb:SetMinMaxValues(0, 1)
	sb:SetStatusBarTexture[[Interface\AddOns\oUF_Lily\textures\statusbar]]

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
		groups[self.owner]:UnregisterBar(self.id)
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
	self.sb:SetValue(percent)
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
			bar:SetPoint("TOPLEFT", group.frame, "BOTTOMLEFT")
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
	RegisterGroup = function(self, name, texture, ...)
		assert(3, not groups[name], string.format(L["GROUP_EXISTS"], name))
		local obj = {
			name = name,
			frame = CreateFrame("Frame"),
			texture = texture,
			scale = 1,
			fontSize = 11,
			width = 29,
			height = 26,
			obj = obj,
			bars = {},
			usedBars = {}
		}

		-- Register
		groups[name] = obj

		-- Set defaults
		obj.frame:SetHeight(1)
		obj.frame:SetWidth(1)

		obj.RegisterBar = self.RegisterBar
		obj.UnregisterBar = self.UnregisterBar

		if( select("#", ...) > 0 ) then
			obj.frame:SetPoint(...)
		else
			obj.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
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
		size = group.fontSize or size

		local width, height = group.width, group.height
		frame:SetWidth(width)
		frame:SetHeight(height)

		frame.cd:ClearAllPoints()
		frame.cd:SetPoint("RIGHT", -3, 0)
		frame.cd:SetPoint("TOP", 0, -3)
		frame.cd:SetPoint("BOTTOM", 0, 3)
		frame.cd:SetPoint("LEFT", width-height+3, 0)

		-- Set info the bar needs to know
		frame.r = r or group.baseColor.r
		frame.g = g or group.baseColor.g
		frame.b = b or group.baseColor.b
		frame.owner = group.name
		frame.lastUpdate = startTime
		frame.endTime = startTime + seconds
		frame.secondsLeft = seconds
		frame.startSeconds = seconds
		frame.gradients = group.gradients
		frame.groupName = group.name
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
