AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

ENT.DisableDuplicator = true
ENT.DoNotDuplicate = true
ENT.FOV = 0
ENT.Viewers = {}

function ENT:Initialize() self:SetNoDraw(true) end

function ENT:NewPosLerp(duration, end_position, start_position)
	--start_position is optional
	self:SetPosDuration(duration)
	self:SetPosEnd(end_position)
	self:SetPosLerping(true)
	self:SetPosStart(start_position or self:GetPos())
	self:SetPosStartTime(CurTime())
end

function ENT:PerformPosLerp(age)
	--called every tick when the camera has a lerp going
	if age < self.NWPosDuration then self:SetPos(LerpVector(age / self.NWPosDuration, self.NWPosStart, self.NWPosEnd))
	else
		self:SetPos(self.NWPosEnd)
		self:SetPosLerping(false)
	end
end

function ENT:SetupDefaultData()
	self:SetPosDuration(0)
	self:SetPosEnd(vector_origin)
	self:SetPosLerping(false)
	self:SetPosStart(vector_origin)
	self:SetPosStartTime(0)
end

function ENT:UpdateTransmitState() return TRANSMIT_PVS end