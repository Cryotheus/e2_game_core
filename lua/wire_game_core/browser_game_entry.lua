local PANEL = {}

local associated_colors = include("colors.lua")

function PANEL:Paint(width, height)
	if self.Depressed or self:IsSelected() or self:GetToggle() then fl_surface_SetDrawColor(color_expression)
	elseif not self:IsEnabled() then fl_surface_SetDrawColor(color_dark_baseboard)
	elseif self.Hovered then fl_surface_SetDrawColor(color_dark_button_hover)
	else fl_surface_SetDrawColor(color_dark_button) end
	
	fl_surface_DrawRect(0, 0, width, height)
end

function PANEL:Init()
	
end

derma.DefineControl("WGCBrowserGameEntry", "A game entry for E2 Game Core", PANEL, "DButton")
