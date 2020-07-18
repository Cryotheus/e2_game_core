ENT.Base = "base_point"
ENT.Editable = false
ENT.Spawnable = false
ENT.Type = "point"

function ENT:NetworkVarChanging(name, old, new) self["NW" .. name] = new end

function ENT:SetupDataTables()
	--everything is prefixed with Pos because I want to add an angle lerp later
	self:NetworkVar("Bool", 0, "PosLerping")
	self:NetworkVar("Float", 0, "PosDuration")
	self:NetworkVar("Float", 1, "PosStartTime")
	self:NetworkVar("Vector", 0, "PosEnd")
	self:NetworkVar("Vector", 1, "PosStart")
	
	--the client doesn't have this, but it may in the future, and this is just to make it so I don't have to go back and remove it immediately when I add it
	if self.SetupDefaultData then self:SetupDefaultData() end
	
	--this makes it so we don't have to use the function calls to fetch the values, because the functions are slower than they should be
	for name, value in pairs(self:GetNetworkVars()) do
		self["NW" .. name] = value
		
		--won't run right after spawn :/
		self:NetworkVarNotify(name, self.NetworkVarChanging)
	end
end

function ENT:Think()
	local cur_time = CurTime()
	
	if self.NWPosLerping then self:PerformPosLerp(cur_time - self.NWPosStartTime) end
	
	--this makes it run every tick, not more or less
	self:NextThink(cur_time)
	
	return true
end