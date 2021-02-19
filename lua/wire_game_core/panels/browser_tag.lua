local PANEL = {}

----render parameters
	local percent = 0.3
	local percent_inc = 1 - percent
	local threshold = 0.3

--accessor funcs
AccessorFunc(PANEL, "TagColor", "TagColor")

surface.CreateFont("WGCBrowserTag", {
	font = "Roboto",
	size = 14,
	weight = 1000
})

--panel functions
function PANEL:Init()
	self:SetContentAlignment(5)
	self:SetFont("WGCBrowserTag")
	self:SetTagColor(255, 0, 0)
end

function PANEL:Paint(width, height) draw.RoundedBox(6, 0, 0, width, height, self.TagColor) end

function PANEL:PerformLayout(width, height)
	surface.SetFont(self:GetFont())
	
	local text_width, text_height = surface.GetTextSize(language.GetPhrase(self:GetText()))
	
	self:SetSize(text_width + 8, text_height + 4)
end

function PANEL:SetTagColor(r, g, b)
	local color = isnumber(r) and Color(r, g or 0, b or 0) or r
	local h, s, v = ColorToHSV(color)
	
	self:SetTextColor(s * percent + (1 - v) * percent_inc < threshold and color_black or color_white)
	
	self.TagColor = color
end

--post
derma.DefineControl("WGCBrowserTag", "A panel for the Wire Game Core's Game Browser.", PANEL, "DLabel")