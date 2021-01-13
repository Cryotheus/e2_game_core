AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

ENT.DisableDuplicator = true
--ENT.DoNotDuplicate = true
ENT.FOV = 0
ENT.Viewers = {}

function ENT:Initialize() self:SetNoDraw(true) end

function ENT:NewPosBezierLerp(duration, end_position, control_position, start_position)
	--start_position is optional
	self:SetPosBezierLerping(true)
	self:SetPosControl(control_position)
	self:SetPosDuration(duration)
	self:SetPosEnd(end_position)
	self:SetPosLerping(false)
	self:SetPosStart(start_position or self:GetPos())
	self:SetPosStartTime(CurTime())
end

function ENT:NewPosLerp(duration, end_position, start_position)
	--start_position is optional
	self:SetPosBezierLerping(false)
	self:SetPosDuration(duration)
	self:SetPosEnd(end_position)
	self:SetPosLerping(true)
	self:SetPosStart(start_position or self:GetPos())
	self:SetPosStartTime(CurTime())
end

function ENT:SetupDefaultData()
	self:SetPosDuration(0)
	self:SetPosEnd(vector_origin)
	self:SetPosLerping(false)
	self:SetPosStart(vector_origin)
	self:SetPosStartTime(0)
end

function ENT:UpdateTransmitState() return TRANSMIT_PVS end