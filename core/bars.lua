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

local class = CreateFrame"Cooldown"
local mt = {__index = class}

local timers = {}

-- locals
local GetTime = GetTime
local string_format = string.format
local math_fmod = math.fmod
local math_floor = math.floor

-- frame pools
local active = {}
local inactive = {}

-- remove these later on
oCD.active = active
oCD.inactive = inactive

local prev
local sorty = function()
	prev = nil
	for k, v in pairs(active) do
		v:ClearAllPoints()
		
		if(prev) then v:SetPoint("TOP", prev, "BOTTOM")
		else v:SetPoint("CENTER", UIParent, 0, 350) end

		prev = v
	end
end

local formatTime = function(time)
	local m, s, text
	if(time <= 0) then
		return ""
	elseif(time < 10) then
		text = string_format("%.1f", time)
	else
		m = math_floor(time / 60)
		s = math_fmod(time, 60)
		text = (m == 0 and string_format("%d", s)) or string_format("%d:%02d", m, s)
	end

	return text
end

-- remove later
oCD.formatTime = formatTime

local now, time
local OnUpdate = function(self, elapsed)
	self.time = self.time + elapsed
	if(self.time > .05) then
		now = GetTime()
		if(self.max > now) then
			time = formatTime(self.max-now)
			self.value:SetText(time)

			if(time == "3.0") then self.value:SetTextColor(.8, .1, .1) end
		end
	
		self.time = 0
	end
end
local OnHide = function(self)
	self.stop(self.name)
end

local sb
local new = function(name)
	sb = CreateFrame"Cooldown"
	setmetatable(sb, mt)

	sb.name = name
	sb.time = 0
	sb:SetParent(UIParent)
	sb:SetHeight(18)
	sb:SetWidth(18)
	sb:SetScript("OnUpdate", OnUpdate)
	sb:SetScript("OnHide", OnHide)

	local icon = sb:CreateTexture(nil, "BACKGROUND")
	icon:SetAllPoints(sb)
	icon:SetAlpha(.6)

	local text = sb:CreateFontString(nil, "OVERLAY")
	text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
	text:SetPoint("LEFT", sb, "RIGHT", 2, 0)

	sb.value = text
	sb.icon = icon
	return sb
end

local old = function(name)
	sb = inactive[name]
	if(sb) then inactive[name] = nil end
	return sb
end

function class.register(name, duration, texture)
	if(timers[name]) then return end

	timers[name] = {
		texture = texture,
		duration = duration,
	}
end

local data, sb
function class.start(name, start, duration)
	data = timers[name]
	if(not data) then return end

	sb = old(name) or active[name] or new(name)
	active[name] = sb

	sb.max = start+duration
	sb:Show()
	sb.icon:SetTexture(data.texture)
	sb:SetCooldown(start, duration)
	sb.value:SetTextColor(1, 1, 1)

	sorty()
end

function class.stop(name)
	if(not active[name]) then return end

	sb = active[name]
	
	sb:Hide()
	inactive[name] = sb
	active[name] = nil

	sorty()
end

oCD.bars = class
