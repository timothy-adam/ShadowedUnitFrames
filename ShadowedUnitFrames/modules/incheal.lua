local IncHeal = {frameKey = "incHeal", colorKey = "inc", frameLevelMod = 3}
ShadowUF.IncHeal = IncHeal
ShadowUF:RegisterModule(IncHeal, "incHeal", ShadowUF.L["Incoming heals"])
ShadowUF.Tags.customEvents["HEALCOMM"] = IncHeal

function IncHeal:OnEnable(frame)
	frame.incHeal = frame.incHeal or ShadowUF.Units:CreateBar(frame)

	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_HEALTH", self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_HEAL_PREDICTION", self, "UpdateFrame")
	frame:RegisterUpdateFunc(self, "UpdateFrame")
end

function IncHeal:OnDisable(frame)
	frame:UnregisterAll(self)
	frame.incHeal:Hide()

	if( frame.hasHCTag ) then
		frame:RegisterUnitEvent("UNIT_HEAL_PREDICTION", self, "UpdateFrame")
		frame:RegisterUpdateFunc(self, "UpdateFrame")
	end
end

function IncHeal:OnLayoutApplied(frame)
	local bar = frame[self.frameKey]
	if( not frame.visibility[self.frameKey] or not frame.visibility.healthBar ) then return end

	if( self.frameKey == "incHeal" and frame.visibility.healAbsorb ) then
		frame:RegisterUnitEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", self, "UpdateFrame")
	elseif( self.frameKey == "incHeal" ) then
		frame:UnregisterSingleEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", self)
	end

	bar.total = nil
	bar.healed = nil
	bar:SetHeight(frame.healthBar:GetHeight())
	bar:SetStatusBarTexture(ShadowUF.Layout.mediaPath.statusbar)
	bar:SetStatusBarColor(ShadowUF.db.profile.healthColors[self.colorKey].r, ShadowUF.db.profile.healthColors[self.colorKey].g, ShadowUF.db.profile.healthColors[self.colorKey].b, ShadowUF.db.profile.bars.alpha)
	bar:GetStatusBarTexture():SetHorizTile(false)
	bar:Hide()

	local cap = ShadowUF.db.profile.units[frame.unitType][self.frameKey].cap or 1.30

	-- An opaque primary bar can cover the predicted bars, avoiding overlapping alpha.
	if( ( ShadowUF.db.profile.units[frame.unitType].healthBar.invert and ShadowUF.db.profile.bars.backgroundAlpha == 0 ) or ( not ShadowUF.db.profile.units[frame.unitType].healthBar.invert and ShadowUF.db.profile.bars.alpha == 1 ) ) then
		bar.simple = true
		bar:SetWidth(frame.healthBar:GetWidth() * cap)
		bar:SetFrameLevel(frame.topFrameLevel - self.frameLevelMod)

		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", frame.healthBar)
		bar:SetPoint("BOTTOMLEFT", frame.healthBar)
	else
		bar.simple = nil
		bar:SetFrameLevel(frame.topFrameLevel - self.frameLevelMod + 3)
		bar:SetWidth(1)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(1)

		bar:ClearAllPoints()
		bar.healthWidth = frame.healthBar:GetWidth()
		bar.maxWidth = bar.healthWidth * cap
	end
end

-- HEALCOMM remains the custom tag event name for profile compatibility.
function IncHeal:EnableTag(frame)
	frame.hasHCTag = true
	frame:RegisterUnitEvent("UNIT_HEAL_PREDICTION", self, "UpdateFrame")
	frame:RegisterUpdateFunc(self, "UpdateFrame")
end

function IncHeal:DisableTag(frame)
	frame.hasHCTag = nil

	if( not frame.visibility.incHeal ) then
		frame:UnregisterAll(self)
	end
end

function IncHeal:UpdateTags(frame, amount)
	if( not frame.fontStrings or not frame.hasHCTag ) then return end

	for _, fontString in pairs(frame.fontStrings) do
		if( fontString.HEALCOMM ) then
			fontString.incoming = amount > 0 and amount or nil
			fontString:UpdateTags()
		end
	end
end

function IncHeal:PositionBar(frame, amount)
	local bar = frame[self.frameKey]
	if( amount <= 0 ) then
		bar.total = nil
		bar.healed = nil
		bar:Hide()
		return
	end

	local health, maxHealth = UnitHealth(frame.unit), UnitHealthMax(frame.unit)
	if( health <= 0 or maxHealth <= 0 ) then
		bar.total = nil
		bar.healed = nil
		bar:Hide()
		return
	end

	bar:Show()
	bar.healed = self.frameKey == "incHeal" and amount or nil

	if( bar.simple ) then
		bar.total = health + amount
		bar:SetMinMaxValues(0, maxHealth * (ShadowUF.db.profile.units[frame.unitType][self.frameKey].cap or 1.30))
		bar:SetValue(bar.total)
	else
		local healthWidth = bar.healthWidth * (health / maxHealth)
		local amountWidth = bar.healthWidth * (amount / maxHealth)
		local availableWidth = bar.maxWidth - healthWidth
		if( amountWidth > availableWidth ) then
			amountWidth = availableWidth
		end

		if( amountWidth <= 0 ) then
			bar.total = nil
			bar.healed = nil
			bar:Hide()
			return
		end

		bar.total = amount
		bar:SetWidth(amountWidth)
		bar:SetPoint("TOPLEFT", frame.healthBar, "TOPLEFT", healthWidth, 0)
	end
end

function IncHeal:UpdateFrame(frame)
	local amount = UnitGetIncomingHeals(frame.unit) or 0
	self:UpdateTags(frame, amount)

	if( not frame.visibility.incHeal or not frame.visibility.healthBar ) then return end

	local displayedAmount = amount
	if( displayedAmount > 0 and frame.visibility.healAbsorb ) then
		displayedAmount = displayedAmount + (UnitGetTotalHealAbsorbs(frame.unit) or 0)
	end

	self:PositionBar(frame, displayedAmount)
end
