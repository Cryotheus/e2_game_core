local PANEL = {}

AccessorFunc(PANEL, "TagColor", "TagColor")

function PANEL:Init() self:SetTagColor(255, 0, 0) end

function PANEL:Paint(width, height) draw.RoundedBox(4, 0, 0, width, height, self.TagColor) end

function PANEL:PerformLayout(width, height)
	surface.SetFont(self:GetFont())
	
	local text_width, text_height = surface.GetTextSize(language.GetPhrase(self:GetText()))
	
	self:SetSize(text_width, text_height)
end

function PANEL:SetTagColor(r, g, b)
	local color = isnumber(r) and Color(r, g or 0, b or 0) or r
	r, g, b = color.r, color.g, color.b
	
	self:SetTextColor((r ^ 2 + g ^ 2 + b ^ 2) / 195075 > 0.9 and color_black or color_white)
	
	self.TagColor = color
end

derma.DefineControl("WGCBrowserTag", "A panel for the Wire Game Core's Game Browser.", PAENL, "DLabel")