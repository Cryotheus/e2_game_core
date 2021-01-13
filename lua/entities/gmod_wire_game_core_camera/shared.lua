ENT.Base = "base_point"
ENT.Editable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = false
ENT.Type = "point"

function ENT:PerformPosBezierLerp(age)
	--called every tick when the camera has a pos bezier lerp is going, mutually exclusive with PerformPosLerp
	--still here in case I need a server and client variation
	if age < self:GetPosDuration() then
		local control_pos = self:GetPosControl()
		local end_pos = self:GetPosEnd()
		local ratio = age / self:GetPosDuration()
		local ratio_inverse = (1 - ratio)
		local ratio_inverse_sqrd = ratio_inverse ^ 2
		local ratio_mult = 2 * ratio_inverse * ratio
		local ratio_sqrd = ratio ^ 2
		local start_pos = self:GetPosStart()
		
		--thats a lot of math to do in a think function :O
		--also the built in spline is broke or something
		self:SetPos(Vector(
						ratio_inverse_sqrd * start_pos.x + ratio_mult * control_pos.x + ratio_sqrd * end_pos.x,
						ratio_inverse_sqrd * start_pos.y + ratio_mult * control_pos.y + ratio_sqrd * end_pos.y,
						ratio_inverse_sqrd * start_pos.z + ratio_mult * control_pos.z + ratio_sqrd * end_pos.z))
	else
		self:SetPos(self:GetPosEnd())
		self:SetPosBezierLerping(false)
	end
end

function ENT:PerformPosLerp(age)
	--called every tick when the camera has a lerp going
	if age < self:GetPosDuration() then self:SetPos(LerpVector(age / self:GetPosDuration(), self:GetPosStart(), self:GetPosEnd()))
	else
		self:SetPos(self:GetPosEnd())
		self:SetPosLerping(false)
	end
end

function ENT:SetupDataTables()
	--everything is prefixed with Pos because I want to add an angle lerp later
	self:NetworkVar("Bool", 0, "PosLerping")
	self:NetworkVar("Bool", 1, "PosBezierLerping")
	self:NetworkVar("Float", 0, "PosDuration")
	self:NetworkVar("Float", 1, "PosStartTime")
	self:NetworkVar("Vector", 0, "PosEnd")
	self:NetworkVar("Vector", 1, "PosStart")
	self:NetworkVar("Vector", 2, "PosControl")
	
	--the client doesn't have this, but it may in the future, and this is just to make it so I don't have to go back and remove it immediately when I add it
	if self.SetupDefaultData then self:SetupDefaultData() end
end

function ENT:Think()
	local cur_time = CurTime()
	
	if self:GetPosLerping() then self:PerformPosLerp(cur_time - self:GetPosStartTime())
	elseif self:GetPosBezierLerping() then self:PerformPosBezierLerp(cur_time - self:GetPosStartTime()) end
	
	--supposedly makes it run every tick, and not more or less?
	self:NextThink(cur_time)
	
	return true
end