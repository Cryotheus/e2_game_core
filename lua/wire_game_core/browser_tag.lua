local PANEL = {}

AccessorFunc(PANEL, "TagColor", "TagColor")

function PANEL:Init()
	self:SetTagColor(255, 0, 0)
end

function PANEL:Paint(width, height)
	draw.RoundedBox(4, 0, 0, width, height, self.TagColor)
end

function PANEL:SetTagColor()
	
end

derma.DefineControl("WGCBrowserTag", "A tag for the Wire Game Core's Game Browser.", PAENL, "DLabel")