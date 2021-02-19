local PANEL = {}

----accessor funcs
	AccessorFunc(PANEL, "Font", "Font", FORCE_STRING)
	AccessorFunc(PANEL, "TagHeight", "TagHeight", FORCE_NUMBER)
	AccessorFunc(PANEL, "TagSpacingX", "TagSpacingX", FORCE_NUMBER)
	AccessorFunc(PANEL, "TagSpacingY", "TagSpacingY", FORCE_NUMBER)

--panel functions
function PANEL:Add(tag_id, tag_text, tag_color, tag_color_g, tag_color_b)
	--tag_color_g and tag_color_b are optional, as tag_color can be a color instead of number
	--get the existing tag
	local tag = self.Tags[tag_id]
	
	--if we already have a tag there, either remove it or stop here
	if tag then return tag end
	
	tag = vgui.Create("WGCBrowserTag", self)
	
	self:InvalidateLayout()
	tag:SetTagColor(tag_color, tag_color_g, tag_color_b)
	tag:SetText(tag_text or "#wire_game_core.tags." .. tag_id)
	
	self.Tags[tag_id] = tag
	
	return tag
end

function PANEL:Clear()
	for tag_id, tag in pairs(self.Tags) do tag:Remove() end
	
	self:InvalidateLayout()
	
	self.Tags = {}
end

function PANEL:Init()
	self.Tags = {}
	
	self:SetFont()
	self:SetTagHeight()
	self:SetTagSpacingX()
	self:SetTagSpacingY()
end

--function PANEL:Paint(width, height) end

function PANEL:PerformLayout(width, height)
	local x = 0
	local y = 0
	
	for index, tag in ipairs(self:GetChildren()) do
		local tag_w, tag_h = tag:GetSize()
		
		if x + tag_w > width then
			x = 0
			y = y + self.TagHeight + self.TagSpacingY
		end
		
		tag:SetPos(x, y)
		
		x = x + tag_w + self.TagSpacingX
	end
	
	self:SizeToChildren(false, true)
end

function PANEL:RemoveTag(tag_id)
	local tag = self.Tags[tag_id]
	
	if tag then
		self:InvalidateLayout()
		tag:Remove()
		
		self.Tags[tag_id] = nil
	end
end

function PANEL:SetFont(font)
	font = font and tostring(font) or "WGCBrowserTag"
	
	for index, tag in ipairs(self:GetChildren()) do
		tag:InvalidateLayout()
		tag:SetFont(font)
	end
	
	self.Font = font
end

function PANEL:SetTagHeight(height)
	if height then self.TagHeight = height
	else
		surface.SetFont(self.Font)
		
		self.TagHeight = select(2, surface.GetTextSize([[~!@#$%^&*()_+QWERTYUIOP{}|ASDFGHJKL:"ZXCVBNM<>?`1234567890-=qwertyuiop[]\asdfghjkl;'zxcvbnm,./]])) + 4
	end
end

function PANEL:SetTagSpacingX(spacing)
	self.TagSpacingX = spacing and tonumber(spacing) or 4
	
	self:InvalidateLayout()
end

function PANEL:SetTagSpacingY(spacing)
	self.TagSpacingY = spacing and tonumber(spacing) or 4
	
	self:InvalidateLayout()
end

--post
derma.DefineControl("WGCBrowserTagContainer", "A panel for the Wire Game Core's Game Browser.", PANEL, "DSizeToContents")