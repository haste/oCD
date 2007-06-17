--[[-------------------------------------------------------------------------
  Copyright (c) 2006-2007, Trond A Ekseth
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are
  met:

      * Redistributions of source code must retain the above copyright
        notice, this list of conditions and the following disclaimer.
      * Redistributions in binary form must reproduce the above
        copyright notice, this list of conditions and the following
        disclaimer in the documentation and/or other materials provided
        with the distribution.
      * Neither the name of oCD nor the names of its contributors may
        be used to endorse or promote products derived from this
        software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
---------------------------------------------------------------------------]]

local timers = {}
local list = {}

local class = CreateFrame"Cooldown"
local mt = {__index = class, __call = function(self, ...) self:update(...) end}

local GetTime = GetTime
local string_format = string.format
local math_fmod = math.fmod
local math_floor = math.floor

-- Settings:
local min, max, growth

local formatTime = function(time)
	local m, s, text
	if(time < 0) then
		return
	elseif(time < 10) then
		text = string_format("%.1f", time)
	else
		m = math_floor(time / 60)
		s = math_fmod(time, 60)
		text = (m == 0 and string_format("%d", s)) or string_format("%d:%02d", m, s)
	end

	return text
end

local sort = function(a, b)
	return a.max > b.max
end

-- TODO: Create a frame we can move around.
local updatePosition = function()
	table.sort(list, sort)

	local prev
	for _, obj in ipairs(list) do
		obj:ClearAllPoints()

		if(prev) then
			obj:SetPoint("TOP", prev, "BOTTOM")
		else
			obj:SetPoint("CENTER", UIParent, 0, 350)
		end

		prev = obj
	end
end

-- TODO: Remove the global reference to these table.
oCD.list = list
oCD.timers = timers
oCD.pos = updatePosition

local now, time
local OnUpdate = function(self, elapsed)
	self.time = self.time + elapsed
	if(self.time > .03) then
		now = self.max-GetTime()
		if(now >= 0) then
			time = formatTime(now)
			self.value:SetText(time)

			if(time == "3.0") then self.value:SetTextColor(.8, .1, .1) end
		else
			self.time = 0
			self:Hide()
		end
	
		self.time = 0
	end
end

local OnHide = function(self)
	for k, v in ipairs(list) do
		if(v.name == self.name and v.time == 0) then
			table.remove(list, k)
		end
	end

	updatePosition()
end

local new = function(name, texture, spellid, type)
	local sb = setmetatable(CreateFrame"Cooldown", mt)
	sb:Hide()

	sb.name = name
	sb.time = 0

	sb.spellid = spellid
	sb.type = type

	sb:SetParent(UIParent)
	sb:SetHeight(20)
	sb:SetWidth(20)
	sb:SetScript("OnUpdate", OnUpdate)
	sb:SetScript("OnHide", OnHide)

	local icon = sb:CreateTexture(nil, "BACKGROUND")
	icon:SetTexture(texture)
	icon:SetAllPoints(sb)
	icon:SetAlpha(.6)

	local text = sb:CreateFontString(nil, "OVERLAY")
	text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")

	sb.value = text
	sb.icon = icon

	return sb
end

-- TODO: Add grouping here:
function class.register(name, texture, spellid, type)
	if(timers[name]) then return end
	timers[name] = new(name, texture, spellid, type)

	return timers[name]
end

function class:update(name, time, duration)
	if(duration == 0 and self:IsShown()) then
		self.time = 0
		self:Hide()
	elseif(duration > min and duration < max and not self:IsShown()) then
		self.max = time + duration
		self:SetCooldown(time, duration)

		table.insert(list, self)
		updatePosition()

		if(duration > 3) then self.value:SetTextColor(1, 1, 1) end
	end
end

function class.setMinMax(mincd, maxcd)
	min, max = mincd, maxcd
end

local anchors = {
	top		= "BOTTOM#TOP#0#0",
	bottom	= "TOP#BOTTOM#0#0",

	left	= "RIGHT#LEFT#-3#-1",
	right	= "LEFT#RIGHT#3#-1",

	center	= "CENTER#CENTER#0#-1",
}

function class.setTextPosition(pos, x2, y2)
	local p1, p2, x, y = strsplit("#", anchors[pos])

	if(x2 and type(x2) == "number") then x = x + x2 end
	if(y2 and type(y2) == "number") then y = y + y2 end

	if(pos == "hidden") then
		for _, obj in pairs(timers) do
			obj.value:Hide()
		end
	else
		for _, obj in pairs(timers) do
			obj.value:Show()
			obj.value:SetPoint(p1, obj, p2, x, y)
		end
	end

end

oCD.bars = class
