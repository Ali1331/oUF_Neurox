local TEXTURE = "Interface\\AddOns\\SharedMedia\\statusbar\\Glamour4"
local casting = {}
local menu = function(self)
	local unit = self.unit:sub(1, -2)
	local cunit = self.unit:gsub("(.)", string.upper, 1)

	if(unit == "party" or unit == "partypet") then
		ToggleDropDownMenu(1, nil, _G["PartyMemberFrame"..self.id.."DropDown"], "cursor", 0, 0)
	elseif(_G[cunit.."FrameDropDown"]) then
		ToggleDropDownMenu(1, nil, _G[cunit.."FrameDropDown"], "cursor", 0, 0)
	end
end

local short = function(val)
	if(val >= 1e6) then
		return ('%s k'):format(floor(val / 1e3))
	end
	return val
end

local superShort = function(val)
	if val >= 1e3 then
		if val >= 1e6 then
			return ('%sm'):format(floor(val/1e6))
		end
		return ('%sk'):format(floor(val/1e3))
	else
		return val
	end
end

local updateName = function(self, event, unit)
	if(self.unit == unit) and unit ~= "player" and unit ~= "vehicle" then
		local r, g, b, t
		if(UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) or not UnitIsConnected(unit)) then
			r, g, b = .6, .6, .6
		elseif(unit == 'pet') then
			t = self.colors.happiness[GetPetHappiness()]
		elseif(UnitIsPlayer(unit)) then
			local _, class = UnitClass(unit)
			t = self.colors.class[class]
		else
			t = self.colors.reaction[UnitReaction(unit, "player")]
		end

		if (t) then
			r, g, b = t[1], t[2], t[3]
		end
		if (r) then
			self.Name:SetTextColor(r, g, b)
		end
		if not self.Castbar:IsShown() and casting[unit] == true then
			casting[unit] = false
		end
		if casting[unit] == false then
			if self.Name.level then
				local lev = UnitLevel(unit)
				if lev == -1 then
					self.Name.level:SetText(" |cff990000??|r")
				else
					local c = GetQuestDifficultyColor(lev)
					self.Name.level:SetText(" "..string.format("|cff%02x%02x%02x", c.r*255, c.g*255, c.b*255)..lev.."|r")
				end
			end
			self.Name:SetText(UnitName(unit))
		end
	end
end

local PostUpdateHealth = function(Health, unit, min, max)
	if(UnitIsDead(unit)) then
		Health:SetValue(0)
	elseif(UnitIsGhost(unit)) then
		Health:SetValue(0)
	end
	return updateName(Health:GetParent(), 'PostUpdateHealth', unit)
end

oUF.Tags["neurox:health"] = function(unit)
	if UnitIsDead(unit) then
		return "Dead"
	elseif UnitIsGhost(unit) then
		return "Ghost"
	elseif not UnitIsConnected(unit) then
		return "Offline"
	else
		local min, max = UnitHealth(unit), UnitHealthMax(unit)	
		if unit == "player" or unit == "target" then
			return string.format('%s / %s %.0f%%', short(min), short(max), (min/max)*100)
		else
			return string.format('%.0f%%', (min/max)*100)
		end
	end
end	
oUF.TagEvents['neurox:health'] = oUF.TagEvents.missinghp

local PostCastStart = function(bar, unit, spell, spellRank)
	local p = bar:GetParent()
	p.Name:SetText(spell)
	if p.Name.level then
		p.Name.level:Hide()
	end
	casting[unit] = true
end

local PostCastStop = function(bar, unit)
	local p = bar:GetParent()
	if unit ~= p.unit then return end
	casting[unit] = false
	if unit == "player" or unit == "vehicle" then
		p.Name:SetFormattedText("%s/%s", short(UnitPower("player")), short(UnitPowerMax("player")))
	else
		--p.Name:SetText(UnitName(unit))
		if p.Name.level then
			p.Name.level:Show()
		end
		updateName(p, 'PostCastStop', unit)
	end
end

local PostCastStopUpdate = function(self, event, unit)
	if(unit ~= self.unit) then return end
	return PostCastStop(self.Castbar, unit)
end

local PostCreateIcon = function(self, button)
	local count = button.count
	count:ClearAllPoints()
	count:SetPoint("BOTTOM")
	button.icon:SetTexCoord(.07, .93, .07, .93)
end

local PostUpdateAuraIcon
do
	local playerUnits = {
		player = true,
		pet = true,
		vehicle = true,
	}
	PostUpdateAuraIcon = function(icons, unit, icon, index, offset, filter, isDebuff)
		local texture = icon.icon
		if(playerUnits[icon.owner]) then
			texture:SetDesaturated(false)
		else
			texture:SetDesaturated(true)
		end
	end
end

local CustomAuraFilter = function(icons, unit, icon, name, rank, texture, count, dtype, duration, timeLeft, caster)
	local isPlayer
	if caster == 'player' or caster == 'vehicle' then
		isPlayer = true
	end
	if timeLeft == 0 then
		icon.timeLeft = math.huge
	else
		icon.timeLeft = timeLeft
	end
	if (icons.onlyShowPlayer and isPlayer) or (not icons.onlyShowPlayer and name) then
		icon.isPlayer = isPlayer
		icon.owner = caster
		return true
	end
end

local sort = function(a, b)
	return a.timeLeft > b.timeLeft
end

local PreAuraSetPosition = function(self, auras, max)
	table.sort(auras, sort)
end

local PostUpdatePower = function(bar, unit, min, max)
	if (unit == "player" or unit == "vehicle") and not casting[unit] then
		if not UnitIsConnected(unit) or UnitIsDead(unit) or UnitIsGhost(unit) then
			bar:SetValue(0)
		end
		bar:GetParent().Name:SetFormattedText("%s/%s", short(min), short(max))
	end
end

local RAID_TARGET_UPDATE = function(self, event)
	local index = GetRaidTargetIndex(self.unit)
	if index then
		self.RIcon:SetText(ICON_LIST[index].."22|t")
	else
		self.RIcon:SetText()
	end
end

local UnitSpecific = {
	player = function(self, ...)
		self:SetSize(270, 30)
		self.Health:SetWidth(268)	
		
		local pp = CreateFrame("StatusBar", nil, self)
		pp:SetHeight(4)
		pp:SetWidth(268)
		pp:SetStatusBarTexture(TEXTURE)
		pp.frequentUpdates = true
		pp.colorTapping = true
		pp.colorHappiness = true
		pp.colorClass = true
		pp.colorReaction = true
		pp:SetParent(self)
		pp:SetPoint("TOP", self.Health, "BOTTOM", 0, -1)
		self.Power = pp
		self.Power.PostUpdate = PostUpdatePower		
		local ppg = self.Health:CreateTexture(nil, "BORDER")
		ppg:SetAllPoints(pp)
		ppg:SetTexture(TEXTURE)		
		ppg.multiplier = 0.5
		self.Power.bg = ppg	
		
		local rest = pp:CreateTexture(nil, "OVERLAY")
		rest:SetSize(20, 16)
		rest:SetPoint("CENTER", self, "BOTTOMLEFT")
		self.Resting = rest		
		
		self.Name:SetTextColor(unpack(self.colors.class[select(2, UnitClass("player"))]))
		self.Name:SetFormattedText("%s/%s", short(UnitPower("player")), short(UnitPowerMax("player")))	
		
		if UnitClass("player") == "Death Knight" then
			self.Runes = CreateFrame('Frame', nil, self)
			self.Runes:SetPoint('TOPLEFT', self, 'BOTTOMLEFT', 0, -1)
			self.Runes:SetHeight(7)
			self.Runes:SetWidth(230)
			self.Runes.anchor = "TOPLEFT"
			self.Runes.growth = "RIGHT"
			self.Runes.height = 7
			self.Runes.width = 230 / 6 - 0.85

			for i = 1, 6 do
				self.Runes[i] = CreateFrame("StatusBar", nil, self.Runes)
				self.Runes[i]:SetStatusBarTexture(TEXTURE)
			end
		end
		
		local debuffs = CreateFrame("Frame", nil, self)
		debuffs:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT")
		debuffs["growth-x"] = "LEFT"
		debuffs.initialAnchor = "TOPRIGHT"
		debuffs:SetHeight(27)
		debuffs:SetWidth(10 * 27)
		debuffs.num = 10
		debuffs.size = 27
		debuffs.PostCreateIcon = PostCreateIcon
		self.Debuffs = debuffs

		self.CustomAuraFilter = CustomAuraFilter
		self.PreAuraSetPosition = PreAuraSetPosition
		self.PostUpdateAuraIcon = PostUpdateAuraIcon		
	end,
	pet = function(self, ...)
		self:SetSize(160, 25)
		self.Health:SetWidth(158)	
		self:RegisterEvent("UNIT_HAPPINESS", updateName)
	end,
	target = function(self, ...)
		self:SetSize(270, 30)
		self.Health:SetWidth(268)	
		
		local level = self.Health:CreateFontString(nil, "OVERLAY")
		level:SetPoint("LEFT", self.Name, "RIGHT")
		level:SetJustifyH("LEFT")
		level:SetFont("Interface\\AddOns\\SharedMedia\\fonts\\BigNoodleTitling.ttf", 14)
		level:SetTextColor(1, 1, 1)
		self.Name.level = level		
		
		local pp = CreateFrame("StatusBar", nil, self)
		pp:SetHeight(4)
		pp:SetWidth(268)
		pp:SetStatusBarTexture(TEXTURE)
		pp.frequentUpdates = true
		pp.colorTapping = true
		pp.colorHappiness = true
		pp.colorClass = true
		pp.colorReaction = true
		pp:SetParent(self)
		pp:SetPoint("TOP", self.Health, "BOTTOM", 0, -1)
		self.Power = pp
		local ppg = self.Health:CreateTexture(nil, "BORDER")
		ppg:SetAllPoints(pp)
		ppg:SetTexture(0.3, 0.3, 0.3)		
		ppg.multiplier = 0.5
		self.Power.bg = ppg
	
		local class = UnitClass("player")
		if class == "Rogue" or class == "Druid" then
			local CPoints = {}
			for index = 1, MAX_COMBO_POINTS do
			   local CPoint = self:CreateTexture(nil, 'BACKGROUND')
			   CPoint:SetSize(15, 15)
			   CPoint:SetTexture("Interface\\AddOns\\oUF_Neurox\\combo")
			   CPoint:SetVertexColor(0.9, 0.2, 0.2)
			   CPoint:SetPoint('TOPLEFT', self, 'BOTTOMLEFT', (index-1) * CPoint:GetWidth(), 0)
			   CPoints[index] = CPoint
			end
			self.CPoints = CPoints
		end
	
		local buffs = CreateFrame("Frame", nil, self)
		buffs.initialAnchor = "BOTTOMLEFT"
		buffs["growth-x"] = "RIGHT"
		buffs:SetPoint("BOTTOMLEFT", self, "TOPLEFT")
		buffs:SetHeight(27)
		buffs:SetWidth(10 * 27)
		buffs.num = 10
		buffs.size = 27
		buffs.PostCreateIcon = PostCreateIcon
		self.Buffs = buffs

		local debuffs = CreateFrame("Frame", nil, self)
		debuffs:SetPoint("TOPLEFT", self, "TOPRIGHT")
		debuffs.onlyShowPlayer = true
		debuffs.initialAnchor = "BOTTOMLEFT"
		debuffs:SetHeight(30)
		debuffs:SetWidth(10 * 30)
		debuffs.num = 10
		debuffs.size = 30
		debuffs.PostCreateIcon = PostCreateIcon
		self.Debuffs = debuffs

		self.CustomAuraFilter = CustomAuraFilter
		self.PreAuraSetPosition = PreAuraSetPosition
		self.PostUpdateAuraIcon = PostUpdateAuraIcon
	end,
	focus = function(self, ...)
		self:SetSize(160, 25)
		self.Health:SetWidth(158)
	end,
	boss = function(self, ...)
		self:SetSize(160, 25)
		self.Health:SetWidth(158)	
	end,
}
UnitSpecific.targettarget = UnitSpecific.focus
UnitSpecific.boss1 = UnitSpecific.boss
UnitSpecific.boss2 = UnitSpecific.boss
UnitSpecific.boss3 = UnitSpecific.boss
UnitSpecific.boss4 = UnitSpecific.boss

local Shared = function(self, unit, isSingle)
	casting[unit] = false
	self.menu = menu
	self:SetScript("OnEnter", UnitFrame_OnEnter)
	self:SetScript("OnLeave", UnitFrame_OnLeave)
	self:RegisterForClicks("AnyDown")

	local hp = CreateFrame("StatusBar", nil, self)
	hp:SetHeight(23)
	hp:SetStatusBarTexture(TEXTURE)
	hp:SetStatusBarColor(0.15, 0.15, 0.15)	
	hp.frequentUpdates = true
	hp:SetPoint("TOP", self, 0, -1)
	self.Health = hp
	self.Health.PostUpdate = PostUpdateHealth
	
	local hpg = hp:CreateTexture(nil, "BORDER")
	hpg:SetTexture(TEXTURE)
	hpg:SetVertexColor(0.3, 0.3, 0.3)
	hpg:SetAllPoints(self.Health)
	self.Health.bg = hpg
	
	local bg = hp:CreateTexture(nil, "BORDER")
	bg:SetAllPoints(self)
	bg:SetTexture(0, 0, 0)
	self.bg = bg	

	local hpp = hp:CreateFontString(nil, "OVERLAY")
	hpp:SetPoint("RIGHT", hp, -4, 0)
	hpp:SetFont("Interface\\AddOns\\SharedMedia\\fonts\\BigNoodleTitling.ttf", 14)
	hpp:SetTextColor(1, 1, 1)
	self:Tag(hpp, "[neurox:health]")
	hp.value = hpp

	local cb = CreateFrame("StatusBar", nil, self)
	cb:SetStatusBarTexture(TEXTURE)
	cb:SetStatusBarColor(1, .25, .35, .5)
	cb:SetAllPoints(hp)
	cb:SetToplevel(true)
	cb.frequentUpdates = true
	self.Castbar = cb
	self.Castbar.PostChannelStart = PostCastStart
	self.Castbar.PostCastStart = PostCastStart
	self.Castbar.PostCastStop = PostCastStop
	self.Castbar.PostChannelStop = PostCastStop

	local leader = self:CreateTexture(nil, "OVERLAY")
	leader:SetHeight(16)
	leader:SetWidth(16)
	leader:SetPoint("BOTTOM", hp, "TOP", 0, -5)
	self.Leader = leader

	local masterlooter = self:CreateTexture(nil, 'OVERLAY')
	masterlooter:SetHeight(16)
	masterlooter:SetWidth(16)
	masterlooter:SetPoint('LEFT', leader, 'RIGHT')
	self.MasterLooter = masterlooter

	local ricon = hp:CreateFontString(nil, "OVERLAY")
	ricon:SetPoint("CENTER", self, "TOPLEFT")
	ricon:SetFont("Interface\\AddOns\\SharedMedia\\fonts\\BigNoodleTitling.ttf", 14)
	ricon:SetTextColor(1, 1, 1)

	self.RIcon = ricon
	self:RegisterEvent("RAID_TARGET_UPDATE", RAID_TARGET_UPDATE)
	table.insert(self.__elements, RAID_TARGET_UPDATE)

	local name = hp:CreateFontString(nil, "OVERLAY")
	name:SetPoint("LEFT", hp, 4, 0)
	name:SetJustifyH("LEFT")
	name:SetFont("Interface\\AddOns\\SharedMedia\\fonts\\BigNoodleTitling.ttf", 14)
	name:SetTextColor(1, 1, 1)
	self.Name = name
	
	self:RegisterEvent('UNIT_NAME_UPDATE', PostCastStop)
	table.insert(self.__elements, 2, PostCastStop)

	if UnitSpecific[unit] then
		UnitSpecific[unit](self)
	end
end

oUF:RegisterStyle("Neurox", Shared)
oUF:Factory(function(self)
	oUF:SetActiveStyle("Neurox")

	local l = oUF:Spawn("player")
	l:SetPoint("BOTTOM", -175, 280)
	oUF:Spawn("pet"):SetPoint("BOTTOMLEFT", l, "TOPLEFT", 0, 1)
	oUF:Spawn("focus"):SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -1)
	l = oUF:Spawn("target")
	l:SetPoint("BOTTOM", 175, 280)
	oUF:Spawn("targettarget"):SetPoint("TOPRIGHT", l, "BOTTOMRIGHT", 0, -1)
	oUF:Spawn("boss1"):SetPoint("TOPRIGHT", l, "BOTTOMRIGHT", 0, -35)
	oUF:Spawn("boss2"):SetPoint("TOPRIGHT", l, "BOTTOMRIGHT", 0, -61)
	oUF:Spawn("boss3"):SetPoint("TOPRIGHT", l, "BOTTOMRIGHT", 0, -87)
	oUF:Spawn("boss4"):SetPoint("TOPRIGHT", l, "BOTTOMRIGHT", 0, -113)

	for i=1,4 do
		local party = "PartyMemberFrame"..i
		local frame = _G[party]
		frame:UnregisterAllEvents()
		frame.Show = dummy
		frame:Hide()
		_G[party..'HealthBar']:UnregisterAllEvents()
		_G[party..'ManaBar']:UnregisterAllEvents()
	end
end)