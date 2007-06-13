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

local defaults = {
	min = 1.5,
	max = 15*60,
	textPos = "right",
	growth = "down",
}

local addon = CreateFrame"Frame"
addon:Hide()

local print = function(...) ChatFrame1:AddMessage(...) end
local printf = function(...) ChatFrame1:AddMessage(string.format(...)) end

-- we run 1.5 across the board, it's possible to have 1.5 seconds global cooldown on a rogue.
local gc = 1.5

--[[ tooltip madness
--]]
local tip = CreateFrame"GameTooltip"
tip:SetOwner(WorldFrame, "ANCHOR_NONE")
tip.r, tip.l = {}, {}

for i=1,8 do
	tip.l[i], tip.r[i] = tip:CreateFontString(nil, nil, "GameFontNormal"), tip:CreateFontString(nil, nil, "GameFontNormal")
	tip:AddFontStrings(tip.l[i], tip.r[i])
end

local SetSpell = function(id, type)
	tip:ClearLines()
	tip:SetSpell(id, type)
end

-- TODO: This should be the defaults of ../locale/enUS.lua.
local min = SPELL_RECAST_TIME_MIN:gsub("%%%.3g", "%(%%d+%%.?%%d*%)")
local sec = SPELL_RECAST_TIME_SEC:gsub("%%%.3g", "%(%%d+%%.?%%d*%)")

-- TODO: Remove the global reference to this table.
local timers = {}
addon.timers = timers

local time, duration, enable
local updateCooldown = function(self)
	for name, obj in pairs(timers) do
		time, duration, enable = GetSpellCooldown(obj.spellid, obj.type)

		obj(name, time, duration)
	end
end

addon.PLAYER_ENTERING_WORLD = updateCooldown

--[[ We delay these events as they can trigger extra scans.
--]]
local show = function(unit) if(not unit or unit == "player") then addon:Show() end end
addon.UNIT_SPELLCAST_SUCCEEDED = show
addon.UNIT_SPELLCAST_STOP = show
addon.UPDATE_STEALTH = show

--[[ Initiate the addon
--]]
local register
function addon:PLAYER_LOGIN()
	register = self.bars.register
	self:parseSpellBook(BOOKTYPE_SPELL)

	self.bars:setMinMax(defaults.min, defaults.max)
	self.bars:setTextPosition(defaults.textPos)
end

function addon:parseSpellBook(type)
	local i, n, n2, r, cd = 1
	while true do
		n, r = GetSpellName(i, type)
		n2 = GetSpellName(i+1, type)
		if not n then break end
		
		if(n ~= n2) then
			SetSpell(i, type)

			cd = tip.r[3]:GetText() or tip.r[2]:GetText()
			if(cd and (cd:match(min) or cd:match(sec))) then
				-- register(name, cd, texture, spellid, type)
				timers[n] = register(n, GetSpellTexture(i, type), i, type)
			end
		end

		i = i + 1
	end
end

--[[ We delay all updates with .5 sec
--]]
local update = 0
addon:SetScript("OnUpdate", function(self, elapsed)
	update = update + elapsed
	if(update > .5) then
		updateCooldown()

		update = 0
		self:Hide()
	end
end)
addon:SetScript("OnEvent", function(self, event, ...)
	self[event](self, event, ...)
end)

addon:RegisterEvent"PLAYER_LOGIN"
addon:RegisterEvent"PLAYER_ENTERING_WORLD"

--[[ I decided to avoid SPELL_UPDATE_COOLDOWN, as it fires a lot..
--   we shave off some CPU usage by doing this instead.
--]]
addon:RegisterEvent"UNIT_SPELLCAST_SUCCEEDED"
addon:RegisterEvent"UNIT_SPELLCAST_STOP"
addon:RegisterEvent"UPDATE_STEALTH"

_G.oCD = addon
