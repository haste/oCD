--[[-------------------------------------------------------------------------
  Copyright (c) 2006-2008, Trond A Ekseth
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

local db = {
	spells = {
		-- Priest
		["Vampiric Embrace"] = true,
		["Shadow Word: Death"] = true,
		["Psychic Scream"] = true,
		["Shadowfiend"] = true,
		["Mind Blast"] = true,
		["Fade"] = true,

		-- Rogue
		['Vanish'] = true,
	},
	items = {
		[29370] = true,
		[44014] = true,
	},
	settings = {
		-- statusbar
		statusbar = {
			size = 4,
			point = "LEFT",
			gradients = true,
			orientation = "VERTICAL",
			texture = [[Interface\AddOns\oCD\textures\smooth]],
		},
		frame = {
			size = 30,
			scale = 1,
			point = "TOP",
			xOffset = 5,
			yOffset = -5,
			columnSpacing = 0,
			columnMax = 1,
			columnAnchorPoint = "RIGHT",
		},
	},
}

local addon = CreateFrame"Frame"
local print = function(...) ChatFrame1:AddMessage(...) end
local printf = function(...) ChatFrame1:AddMessage(string.format(...)) end

local tip = CreateFrame"GameTooltip"
tip:SetOwner(WorldFrame, "ANCHOR_NONE")
tip.r, tip.l = {}, {}

for i=1,3 do
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

function addon:PLAYER_LOGIN()
	self.group = self.display:RegisterGroup("oCD", "TOP", "UIErrorsFrame", "BOTTOM")

	for k, v in pairs(db.settings) do
		self.group[k] = v
	end

	self.group:SetBackdropColor(0, 0, 0)
	self.group:SetBackdropBorderColor(0, 0, 0)

	self.group:SetHeight(18 * 3)
	self.group:SetWidth(18 * 2)
end

function addon:parseSpellBook(type)
	local i = 1
	while true do
		local name = GetSpellName(i, type)
		local next = GetSpellName(i+1, type)
		if(not name) then break end
		
		if(name ~= next) then
			SetSpell(i, type)

			local line = tip.r[3]:GetText() or tip.r[2]:GetText()
			if(line and (line:match(sec) or line:match(min))) then
				spells[name] = line:match(sec) or line:match(min)*60
			end
		end

		i = i + 1
	end
end


function addon:SPELL_UPDATE_COOLDOWN()
	for name, obj in pairs(db.spells) do
		local startTime, duration, enabled = GetSpellCooldown(name)

		if(enabled == 1 and duration > 1.5) then
			self.group:RegisterBar(name, startTime, duration, GetSpellTexture(name), 0, 1, 0)
		elseif(enabled == 1) then
			self.group:UnregisterBar(name)
		end
	end
end

function addon:BAG_UPDATE_COOLDOWN()
	for item, obj in pairs(db.items) do
		local startTime, duration, enabled = GetItemCooldown(item)
		if(enabled == 1) then
			self.group:RegisterBar(item, startTime, duration, select(10, GetItemInfo(item)), 0, 1, 0)
		end
	end
end

addon:SetScript("OnEvent", function(self, event, ...)
	self[event](self, event, ...)
end)

addon:RegisterEvent"PLAYER_LOGIN"
addon:RegisterEvent"SPELL_UPDATE_COOLDOWN"
-- TODO: Only register if we actually are watching a cooldown in the container.
addon:RegisterEvent"BAG_UPDATE_COOLDOWN"

_G.oCD = addon
