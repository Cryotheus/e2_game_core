local PANEL = {}

--todo: clean up code style
--silly goose do not pick up the code style of this file

local canvas_animation_curve = math.pi * 0.5

----colors
	local associated_colors = include("wire_game_core/includes/colors.lua")
	local color_dark_baseboard = associated_colors.color_dark_baseboard
	local color_dark_button = associated_colors.color_dark_button
	local color_dark_button_hover = associated_colors.color_dark_button_hover
	local color_dark_header = associated_colors.color_dark_header
	local color_dark_text = associated_colors.color_dark_text
	local color_dark_track = associated_colors.color_dark_track
	local color_expression = associated_colors.color_expression

----cached functions
	local fl_surface_DrawRect = surface.DrawRect
	local fl_surface_DrawTexturedRect = surface.DrawTexturedRect
	local fl_surface_SetDrawColor = surface.SetDrawColor

----accessor functions
	AccessorFunc(PANEL, "Canvas", "Canvas")
	AccessorFunc(PANEL, "CanvasHeight", "CanvasHeight", FORCE_NUMBER)
	AccessorFunc(PANEL, "Description", "Description")
	AccessorFunc(PANEL, "HeaderHeight", "HeaderHeight", FORCE_NUMBER)
	AccessorFunc(PANEL, "Master", "Master")
	AccessorFunc(PANEL, "MasterIndex", "MasterIndex", FORCE_NUMBER)
	AccessorFunc(PANEL, "Open", "Open", FORCE_BOOL)
	AccessorFunc(PANEL, "Score", "Score", FORCE_NUMBER)
	AccessorFunc(PANEL, "Title", "Title", FORCE_STRING)

surface.CreateFont("WGCBrowserGEPlayerName", {
	font = "Roboto",
	size = 24
})

--panel functions
function PANEL:AddTag(...) self.TagContainer:Add(...) end

function PANEL:DoClick()
	local canvas = self.Canvas
	
	canvas:SetActive(not canvas:GetActive())
end

function PANEL:Init()
	self:SetText("")
	
	self.HeaderHeight = self:GetTall()
	
	----header
	do
		local header = vgui.Create("DButton", self)
		
		header:Dock(TOP)
		header:SetFont("DermaLarge")
		header:SetHeight(self.HeaderHeight)
		header:SetTextColor(Color(224, 224, 224))
		
		function header:DoClick() self:GetParent():DoClick() end
		
		function header:Paint(width, height)
			if self.Depressed or self:IsSelected() or self:GetToggle() then
				fl_surface_SetDrawColor(128, 128, 128, 8)
				fl_surface_DrawRect(0, 0, width, height)
			elseif not self:IsEnabled() then
				fl_surface_SetDrawColor(0, 0, 0, 64)
				fl_surface_DrawRect(0, 0, width, height)
			elseif self.Hovered then
				fl_surface_SetDrawColor(128, 128, 128, 4)
				fl_surface_DrawRect(0, 0, width, height)
			end
		end
		
		do --host card panel
			local panel = vgui.Create("DButton", header)
			
			panel:Dock(LEFT)
			panel:DockMargin(0, 4, 0, 4)
			panel:SetText("")
			
			do --player's avatar
				local avatar = vgui.Create("AvatarImage", panel)
				local avatar_set_player = avatar.SetPlayer
				
				avatar:Dock(FILL)
				avatar:DockMargin(4, 0, 4, 4)
				avatar:SetMouseInputEnabled(false)
				
				function avatar:SetPlayer(ply, size)
					avatar_set_player(self, ply, size)
					
					if IsValid(ply) then panel.SteamID64 = ply:SteamID64() end
				end
				
				panel.AvatarHost = avatar
				self.AvatarHost = avatar
			end
			
			do --player name
				--local game_entry = self
				local label = vgui.Create("DLabel", panel)
				
				label:Dock(BOTTOM)
				label:DockMargin(4, 0, 4, 0)
				label:SetContentAlignment(5)
				label:SetFont("DermaDefaultBold")
				label:SetText("#wire_game_core.browser.invalid")
				label:SetTextColor(color_white)
				label:SetMouseInputEnabled(false)
				
				panel.LabelHost = label
				self.LabelHost = label
			end
			
			function panel:DoClick() if self.SteamID64 then gui.OpenURL("http://steamcommunity.com/profiles/" .. self.SteamID64) end end
			
			function panel:Paint() end
			
			function panel:PerformLayout(width, height)
				local label_height = math.max(height - width - 4, 16)
				
				self.LabelHost:SetHeight(label_height)
			end
			
			self.PanelHostCard = panel
		end
		
		do --join button
			local button = vgui.Create("DButton", header)
			
			button:Dock(RIGHT)
			button:DockMargin(0, 4, 4, 4)
			button:SetText("#wire_game_core.browser.join")
			button:SetVisible(false)
			
			function button:Paint(width, height)
				if self.Depressed or self:IsSelected() or self:GetToggle() then fl_surface_SetDrawColor(color_expression)
				elseif not self:IsEnabled() then fl_surface_SetDrawColor(color_dark_button)
				elseif self.Hovered then fl_surface_SetDrawColor(color_dark_button_hover)
				else fl_surface_SetDrawColor(color_dark_baseboard) end
				
				fl_surface_DrawRect(0, 0, width, height)
			end
			
			--auto stretch vertical for the text
			function button:PerformLayout(width, height)
				surface.SetFont("DermaDefault")
				self:SetWidth(math.Clamp(surface.GetTextSize(language.GetPhrase("wire_game_core.browser.join")) + 10, 64, self:GetParent():GetWide() * 0.5))
			end
			
			button.GameEntry = self
			header.ButtonJoin = button
			self.ButtonJoin = button
		end
		
		self.Header = header
	end
	
	do --canvas
		local game_entry = self
		
		----canvas panel
			local panel_canvas = vgui.Create("DPanel", self)
			
			AccessorFunc(panel_canvas, "Active", "Active", FORCE_BOOL)
			
			panel_canvas:SetPos(0, self:GetHeaderHeight())
			panel_canvas:SetSize(self:GetWide(), 0)
			
			panel_canvas.CanvasHeight = 0
			panel_canvas.Contents = {}
			panel_canvas.Percent = 0
			panel_canvas.Speed = 3
			
			function panel_canvas:Paint(width, height) end
			
			function panel_canvas:PerformLayout(width, height)
				local max_height = 0
				
				--calculate the 
				for index, panel in pairs(self:GetChildren()) do
					local y = panel.y or select(2, panel:GetPos()) or 0
					
					max_height = math.max(max_height, panel:GetTall() + y)
				end
				
				self:SetWidth(game_entry:GetWide())
				self:SetCanvasHeight(max_height + 4)
			end
			
			function panel_canvas:Think()
				local old_percent = self.Percent
				local percent = math.Clamp(old_percent + RealFrameTime() * (self.Active and self.Speed or -self.Speed), 0, 1)
				
				if percent ~= old_percent then
					self.Percent = percent
					
					if percent == 0 then
						game_entry:SetHeight(game_entry:GetHeaderHeight())
						
						self:SetHeight(self.CanvasHeight)
						self:SetVisible(false)
					else
						local height = self.CanvasHeight * math.sin(percent * canvas_animation_curve) ^ 0.75
						
						game_entry:SetHeight(height + game_entry:GetHeaderHeight())
						self:SetHeight(height)
					end
				end
			end
			
			function panel_canvas:SetActive(active)
				active = tobool(active) or false
				
				if self.Active ~= active then
					self.Active = active
					
					if active then self:SetVisible(true)
					else self:SetVisible(self.Percent ~= 0) end
				end
			end
			
			function panel_canvas:SetCanvasHeight(height, animate_expansion)
				local canvas_height = self.CanvasHeight
				
				if animate_expansion and height > canvas_height and self.Active then self.Percent = self.Percent * canvas_height / height end
				
				self.CanvasHeight = height
			end
			
			panel_canvas:SetActive(false)
			self:SetCanvas(panel_canvas)
		
		do --add canvas stuff
			do --description panel
				local panel = vgui.Create("DSizeToContents", panel_canvas)
				
				panel:Dock(TOP)
				panel:DockMargin(4, 4, 4, 0)
				
				do --header
					local label = vgui.Create("DLabel", panel)
					
					label:Dock(TOP)
					label:SetAutoStretchVertical(true)
					label:SetContentAlignment(5)
					label:SetFont("DermaLarge")
					label:SetText("#wire_game_core.browser.description")
					
					panel.LabelHeader = label
				end
				
				do --tags
					local tag_container = vgui.Create("WGCBrowserTagContainer", panel)
					
					tag_container:Dock(TOP)
					tag_container:DockMargin(0, 4, 0, 4)
					
					panel.TagContainer = tag_container
					self.TagContainer = tag_container
				end
				
				do --body
					local label = vgui.Create("DLabel", panel)
					
					label:Dock(TOP)
					label:SetAutoStretchVertical(true)
					label:SetContentAlignment(7)
					label:SetText("#wire_game_core.browser.description.empty")
					
					panel.LabelDescription = label
					self.LabelDescription = label
				end
				
				function panel:Paint() end
				
				function panel:PerformLayout(width, height) self:SizeToChildren(false, true) end
				
				panel_canvas.PanelDescription = panel
				self.PanelDescription = panel
			end
			
			do --player panel
				--DSizeToContents
				local panel = vgui.Create("DSizeToContents", panel_canvas)
				
				panel:Dock(TOP)
				panel:DockMargin(4, 4, 4, 0)
				
				do --header
					local label = vgui.Create("DLabel", panel)
					
					label:Dock(TOP)
					label:SetAutoStretchVertical(true)
					label:SetContentAlignment(5)
					label:SetFont("DermaLarge")
					label:SetText("#wire_game_core.browser.players")
					
					panel.LabelHeader = label
					self.LabelPlayersHeader = label
				end
				
				do --body
					
				end
				
				function panel:AddPlayer(ply)
					local panel_player = vgui.Create("DPanel", panel)
					local valid_player = IsValid(ply)
					
					panel_player.Removable = true
					
					panel_player:Dock(TOP)
					panel_player:DockMargin(0, 4, 0, 0)
					
					function panel_player:PerformLayout(width, height) self:SetHeight(64) end
					
					do --avatar
						local avatar = vgui.Create("AvatarImage", panel_player)
						
						avatar:Dock(LEFT)
						avatar:DockMargin(4, 4, 0, 4)
						
						if valid_player then avatar:SetPlayer(ply, 64) end
						
						function avatar:PerformLayout(width, height) self:SetWidth(height) end
					end
					
					do --name and shit
						local label = vgui.Create("DLabel", panel_player)
						
						label:Dock(FILL)
						label:DockMargin(4, 4, 4, 4)
						label:SetFont("WGCBrowserGEPlayerName")
						label:SetText(valid_player and ply:Nick() or "#wire_game_core.browser.invalid")
					end
					
					function panel_player:Paint(width, height)
						fl_surface_SetDrawColor(color_dark_baseboard)
						fl_surface_DrawRect(0, 0, width, height)
					end
				end
				
				function panel:PerformLayout(width, height) self:SizeToChildren(false, true) end
				
				function panel:SetPlayers(plys)
					for index, panel in ipairs(self:GetChildren()) do if panel.Removable then panel:Remove() end end
					for index, ply in ipairs(plys) do self:AddPlayer(ply) end
				end
				
				panel_canvas.PanelPlayers = panel
				self.PanelPlayers = panel
			end
		end
	end
end

function PANEL:Paint(width, height)
	local header_height = self.HeaderHeight
	
	fl_surface_SetDrawColor(color_dark_button)
	fl_surface_DrawRect(0, 0, width, header_height)
	
	fl_surface_SetDrawColor(color_dark_track)
	fl_surface_DrawRect(0, header_height, width, height - header_height)
end

function PANEL:PerformLayout(width, height)
	local canvas = self.Canvas
	local canvas_height = canvas:GetTall()
	local header_height = self:GetHeaderHeight()
	
	canvas:SetWide(width)
	
	self.ButtonJoin:DockMargin(0, 4, 4, header_height * 0.75 + 4)
	self.PanelHostCard:SetWide(math.min(width * 0.2, header_height * 0.7), header_height - 8)
end

function PANEL:RemoveMaster()
	self.Master = NULL
	self.MasterIndex = 0
	
	self.AvatarHost:SetPlayer(NULL, 184)
	self.LabelHost:SetText("#wire_game_core.browser.invalid")
	
	self:SetScore(0)
end

function PANEL:SetCanvasHeight(...) self.Canvas:SetCanvasHeight(...) end

function PANEL:SetDescription(description)
	self.PanelDescription.LabelDescription:SetText(description or self.Master == LocalPlayer() and "#wire_game_core.browser.description.empty.developer" or "#wire_game_core.browser.description.empty")
	
	self.Description = description
end

function PANEL:SetHeaderHeight(height)
	local canvas = self.Canvas
	
	canvas:SetPos(0, height)
	self.Header:SetHeight(height)
	self:SetHeight(height + (canvas.Active and canvas:GetTall() or 0))
	
	self.HeaderHeight = height
end

function PANEL:SetJoinable(joinable)
	if joinable then
		local join_button = self.ButtonJoin
		
		function join_button:DoClick()
			local master_index = self.GameEntry.MasterIndex
			
			if master_index and master_index > 0 then
				net.Start("wire_game_core_join")
				net.WriteInt(master_index, 8)
				net.SendToServer()
				
				self.GameEntry.FrameBrowser:Close()
			else self.GameEntry.Scroller:GenerateGameEntries() end
		end
		
		join_button:SetVisible(true)
	else
		local header = self.Header
		
		header:SetCursor("none")
		header:SetEnabled(false)
		self.ButtonJoin:SetVisible(false)
		self.Canvas:SetActive(false)
	end
end

function PANEL:SetMaster(master)
	self.AvatarHost:SetPlayer(master, 184)
	self.LabelHost:SetText(master:Nick())
	
	self:SetDescription(self.Description)
	
	self.Master = master
end

function PANEL:SetMasterIndex(master_index)
	master_index = tonumber(master_index)
	
	if master_index then
		
		local master = Entity(master_index)
		
		if IsValid(master) then
			self.MasterIndex = master_index
			
			self:SetMaster(master)
			
			return
		end
	end
	
	self:RemoveMaster()
end

function PANEL:SetPlayers(plys) self.PanelPlayers:SetPlayers(plys) end

function PANEL:SetPlayersByEntityIndexKeys(ply_indices)
	local plys = {}
	
	for ply_index in pairs(ply_indices) do table.insert(plys, Entity(ply_index)) end
	
	self.PanelPlayers:SetPlayers(plys)
end

function PANEL:SetTitle(text) self.Header:SetText(text) end

derma.DefineControl("WGCBrowserGameEntry", "A game entry for E2 Game Core.", PANEL, "DPanel")