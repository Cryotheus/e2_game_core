include("shared.lua")

ENT.Author = "Cryotheum"
ENT.AutomaticFrameAdvance = true
ENT.Contact = "Discord: Cryotheum#4096"
ENT.Instructions = "Spawn it using Game Core Eexpression 2 functions."
ENT.PrintName = "Game Core Camera"
ENT.Purpose = "Used to control players' view with Expression 2."

function ENT:PerformPosLerp(age)
	--called every tick when the camera has a lerp going
	if age < self.NWPosDuration then self:SetPos(LerpVector(age / self.NWPosDuration, self.NWPosStart, self.NWPosEnd))
	else self:SetPos(self.NWPosEnd) end
end