--note that I am still working on this, so I have not yet cached rendering functions and there is some other stuff which probably needs to be optimized
--tables
local game_blocks = {}				--y stores the blocked players, may not be used;	k: master index,		v: true
local game_blocks_check_boxes = {}	--y stores the checkbox panel for every player;		k: master index,		v: panel
local game_masters = {}				--y used to fetch the player's game master;			k: player index,		v: master index
local game_settings = {}			--y stores the settings for each players game;		k: master index,		v: table where (k: setting name, v: setting value)
local held_requests = {}			--y stores requests the player has received;		k: sequential index,	v: table where (k: setting num, v: setting data)
local player_physgun_colors = {}	--y stores the color of the player's physgun;		k: player index,		v: color
local player_visibility = 1

local game_master
local game_master_index
local last_alive = false
local me
local me_index
local rad_to_deg = (2 * math.pi) / 360
local settings_form
local weapon_class

--scoped functions
local generate_block_form
local open_browser
local open_request_gui

----colors
	local color_button_text = Color(224, 224, 224)
	local color_dark = Color(26, 26, 26)
	local color_dark_baseboard = Color(28, 28, 28)
	local color_dark_button = Color(36, 36, 36)
	local color_dark_button_hover = Color(42, 42, 42)
	local color_dark_header = Color(44, 44, 44)
	local color_dark_text = Color(96, 96, 96)
	local color_dark_track = Color(31, 31, 31)
	local color_expression = Color(150, 34, 34)
	local color_expression_excited = Color(158, 47, 47)
	local color_game_highlight = Color(128, 255, 128)
	local color_game_indicator = Color(192, 255, 192)
	local color_ghost = Color(255, 255, 255, 127)

--render parameters
local block_form
local button_reload
local browser
local browser_baseboard_h
local browser_button_h
local browser_h
local browser_icon_material = Material("vgui/wire_game_core/icon.png")
local browser_icon_size
local browser_margin = 100
local browser_w
local browser_x
local browser_y
local cog_size
local cog_texture = surface.GetTextureID("expression 2/cog")
local context_menu
local debug_panel_cogs
local game_bar
local player_visibility_function
local game_bar_button_hide_phrases = {"Hide Excluded Players", "Hide All Players", "Reveal Players"}
local game_bar_button_hide_y
local game_bar_button_leave_h
local game_bar_button_leave_w
local game_bar_button_leave_y
local game_bar_button_undecided_y
local game_bar_cogs
local game_bar_desired = false
local game_bar_h
local game_bar_header = 36
local game_bar_open = false
local game_bar_w
local game_bar_x
local game_bar_y
local header = 24
local margin = 4
local margin_double = margin * 2
local margin_half = margin * 0.5
local player_visibility_button
local pop_up
local pop_up_baseboard_h
local pop_up_baseboard_y
local pop_up_button_accept_h
local pop_up_button_accept_w
local pop_up_button_accept_y
local pop_up_button_deny_x
local pop_up_cog_size
local pop_up_cogs
local pop_up_panel_info_h
local pop_up_panel_info_w
local pop_up_panel_info_y
local pop_up_h
local pop_up_w
local scr_h
local scr_w

--constants
local player_visibility_functions = {
	nil,
	function(ply)
		local ply_index = ply:EntIndex()
		local master_index = game_masters[ply_index]
		
		if not master_index or master_index ~= game_master_index then
			return true
		end
	end,
	function(ply) if ply ~= me then return true end end
}

local player_visibility_set_functions = {
	function(ply)
		local ply_index = ply:EntIndex()
		local ply_physgun_color = player_physgun_colors[ply_index]
		
		ply:DrawShadow(true)
		
		if ply_physgun_color then
			ply:SetWeaponColor(ply_physgun_color)
			
			player_physgun_colors[ply_index] = nil
		end
	end,
	function(ply)
		local ply_index = ply:EntIndex()
		local master_index = game_masters[ply_index]
		
		if not master_index or master_index ~= game_master_index then
			ply:DrawShadow(false)
			
			if not player_physgun_colors[ply_index] then
				player_physgun_colors[ply_index] = ply:GetWeaponColor()
				
				ply:SetWeaponColor(vector_origin)
			end
		else
			local ply_physgun_color = player_physgun_colors[ply_index]
			
			ply:DrawShadow(true)
			
			if ply_physgun_color then
				ply:SetWeaponColor(ply_physgun_color)
				
				player_physgun_colors[ply_index] = nil
			end
		end
	end,
	function(ply)
		local ply_index = ply:EntIndex()
		
		ply:DrawShadow(false)
		
		if not player_physgun_colors[ply_index] then
			player_physgun_colors[ply_index] = ply:GetWeaponColor()
			
			ply:SetWeaponColor(vector_origin)
		end
	end
}

--convars
local wire_game_core_request_duration = CreateClientConVar("wire_game_core_request_duration", "30", true, false, "How long should a request last before expiring", 10, 60)

--convar values
local pop_up_duration = wire_game_core_request_duration:GetFloat()

----chached functions
	local fl_cam_End2D = cam.End2D
	local fl_cam_Start2D = cam.Start2D
	local fl_render_Clear = render.Clear
	local fl_render_ClearStencil = render.ClearStencil
	local fl_render_CopyRenderTargetToTexture = render.CopyRenderTargetToTexture
	local fl_render_DrawScreenQuad = render.DrawScreenQuad
	local fl_render_GetRenderTarget = render.GetRenderTarget
	local fl_render_SetMaterial = render.SetMaterial
	local fl_render_SetRenderTarget = render.SetRenderTarget
	local fl_render_SetStencilCompareFunction = render.SetStencilCompareFunction
	local fl_render_SetStencilEnable = render.SetStencilEnable
	local fl_render_SetStencilFailOperation = render.SetStencilFailOperation
	local fl_render_SetStencilPassOperation = render.SetStencilPassOperation
	local fl_render_SetStencilReferenceValue = render.SetStencilReferenceValue
	local fl_render_SetStencilTestMask = render.SetStencilTestMask
	local fl_render_SetStencilWriteMask = render.SetStencilWriteMask
	local fl_render_SetStencilZFailOperation = render.SetStencilZFailOperation
	local fl_surface_DrawRect = surface.DrawRect
	local fl_surface_DrawTexturedRect = surface.DrawTexturedRect
	local fl_surface_DrawTexturedRectRotated = surface.DrawTexturedRectRotated
	local fl_surface_SetDrawColor = surface.SetDrawColor
	local fl_surface_SetMaterial = surface.SetMaterial
	local fl_surface_SetTexture = surface.SetTexture

--local functions
local function active_game() if game_master_index then return true end end
local function active_game_inv() if game_master_index then return false end end

local function add_block_checkbox(ply)
	local check_box = vgui.Create("DCheckBoxLabel", block_form)
	local master_index = ply:EntIndex()
	
	check_box:SetText(ply:Nick())
	check_box:SetTextColor(color_black)
	
	if game_blocks[master_index] then check_box:SetChecked(false)
	else check_box:SetChecked(true) end
	
	if ply == me then
		check_box:SetEnabled(false)
		check_box:SetMouseInputEnabled(false)
		
		function check_box:OnChange(checked) self:SetChecked(true) end
	else
		function check_box:OnChange(checked)
			if IsValid(ply) then
				for master_index, panel in pairs(game_blocks_check_boxes) do panel:SetEnabled(false) end
				
				net.Start("wire_game_core_block")
				net.WriteUInt(master_index, 8)
				net.WriteBool(not checked)
				net.SendToServer()
				
				timer.Create("wire_game_core_block_form_timeout", 5, 1, generate_block_form)
			else self:Remove() end
		end
	end
	
	game_blocks_check_boxes[master_index] = check_box
	
	--we have to do it this way, instead of using :CheckBox because AddItem doesn't run OnChange
	block_form:AddItem(check_box)
end

local function adjust_player_visibility(override)
	local value = override or player_visibility
	
	player_visibility_function = player_visibility_functions[value]
	
	if player_visibility_function then
		local player_visibility_set_function = player_visibility_set_functions[value]
		
		hook.Add("PrePlayerDraw", "wire_game_core", player_visibility_function)
		hook.Add("HUDDrawTargetID", "wire_game_core", function() return true end) --todo: filter this
		
		for _, ply in pairs(player.GetAll()) do
			if ply == me then continue end
			
			player_visibility_set_function(ply)
		end
	else
		local player_visibility_set_function = player_visibility_set_functions[1]
		
		hook.Remove("PrePlayerDraw", "wire_game_core")
		hook.Remove("HUDDrawTargetID", "wire_game_core")
		
		for _, ply in pairs(player.GetAll()) do
			if ply == me then continue end
			
			player_visibility_set_function(ply)
		end
	end
end

local function button_paint(self, w, h)
	if self.Depressed or self:IsSelected() or self:GetToggle() then fl_surface_SetDrawColor(color_expression)
	elseif not self:IsEnabled() then fl_surface_SetDrawColor(color_dark_baseboard)
	elseif self.Hovered then fl_surface_SetDrawColor(color_dark_button_hover)
	else fl_surface_SetDrawColor(color_dark_button) end
	
	fl_surface_DrawRect(0, 0, w, h)
end

local function calc_cogs(start_rate, start_size, start_x, start_y, ideas, debugging)
	local cogs = {}
	local current_angle = 0
	local current_x = start_x
	local current_y = start_y
	local last_cog_index = 1
	local last_size = start_size * cog_size
	
	table.insert(cogs, {
		offset = 0,
		rate = start_rate,
		size = start_size * cog_size,
		x = start_x,
		y = start_y
	})
	
	local constant = 360 / 16 --they all have the same teeth, but they are of different size
	
	for index, idea in pairs(ideas) do
		local calc_size = cog_size * idea.size
		local idea_radius = (calc_size + last_size) * 0.5 * 0.96
		local rate = start_size / idea.size * start_rate * (1 - (index % 2) * 2)
		
		current_angle = (current_angle + idea.angle) % 360
		current_x = current_x + math.cos(current_angle * math.pi / 180) * idea_radius
		current_y = current_y + math.sin(current_angle * math.pi / 180) * idea_radius
		
		--[[ --this is impossible to solve, I swear
		local last_cog = cogs[last_cog_index]
		local joint_angle = math.atan2(current_y, current_x) / math.pi * 180
		local offset = 180 - ( ( last_cog.offset + joint_angle ) * ( calc_size / last_cog.size ) ) - joint_angle
		--]]
		
		last_cog_index = table.insert(cogs, {
			offset = idea.offset,
			--offset = offset,
			rate = rate,
			size = calc_size,
			x = current_x,
			y = current_y
		})
		
		last_size = calc_size
	end
	
	return cogs
end

local function calc_vars()
	local browser_margin_double = browser_margin * 2
	
	scr_h = ScrH()
	scr_w = ScrW()
	
	browser_h = scr_h - browser_margin_double
	browser_w = scr_w - browser_margin_double
	browser_x = browser_margin
	browser_y = browser_margin
	
	browser_baseboard_h = browser_h * 0.2
	browser_icon_size = browser_baseboard_h - margin_double
	
	--so we get almost 5 entries to fit
	browser_button_h = (browser_h - browser_baseboard_h - header) * 0.2
	
	game_bar_animation_curve = 0.5
	game_bar_animation_duration = 0.3
	game_bar_h = scr_h * 0.15
	game_bar_w = scr_w * 0.4
	game_bar_x = (scr_w - game_bar_w) * 0.5
	game_bar_y = scr_h - game_bar_h
	
	game_bar_sidebar_h = game_bar_h - game_bar_header
	game_bar_sidebar_w = game_bar_w * 0.25
	
	game_bar_button_leave_h = game_bar_sidebar_h * 0.25 - margin - margin_half
	game_bar_button_leave_w = game_bar_sidebar_w - margin_double
	game_bar_button_leave_y = game_bar_header + margin
	
	game_bar_button_hide_y = game_bar_button_leave_y + game_bar_button_leave_h + margin
	
	game_bar_button_undecided_y = game_bar_button_hide_y + game_bar_button_leave_h + margin
	
	pop_up_h = scr_h * 0.2
	pop_up_w = scr_w * 0.2
	
	pop_up_panel_info_h = pop_up_h * 0.8 - margin_double - header
	pop_up_panel_info_w = pop_up_w - margin_double
	pop_up_panel_info_y = header + margin
	
	pop_up_button_accept_h = pop_up_h - pop_up_panel_info_h - margin_double - header - margin
	pop_up_button_accept_w = pop_up_w * 0.5 - margin - margin_half
	pop_up_button_accept_y = pop_up_panel_info_h + margin_double + header
	pop_up_button_deny_x = pop_up_button_accept_w + margin_double
	
	cog_size = pop_up_h - header
	
	pop_up_baseboard_h = pop_up_h - pop_up_button_accept_y + margin_double
	pop_up_baseboard_y = pop_up_button_accept_y - margin
	
	game_bar_cogs = calc_cogs(10, 1, 0, 0, {
		{
			angle = 45,
			offset = 12.5,
			size = 0.5
		},
		{
			angle = -20,
			offset = 7,
			size = 1
		},
		{
			angle = 270,
			offset = 14,
			size = 0.5
		},
		{
			angle = 70,
			offset = 3,
			size = 1
		},
		{
			angle = 0,
			offset = 13.5,
			size = 0.5
		},
		{
			angle = 30,
			offset = 18.5,
			size = 0.5
		},
		{
			angle = -40,
			offset = 4.3,
			size = 1
		}
	})
	
	pop_up_cogs = calc_cogs(10, 1, 0, 0, {
		{
			angle = 45,
			offset = 12,
			size = 0.5
		},
		{
			angle = -20,
			offset = 7.5,
			size = 1
		},
		{
			angle = 0,
			offset = 9.7,
			size = 2
		}
	})
	
	if game_bar and not game_bar_animating then
		--reposition the bar if it exists, I only imagine this happening if the screen resolution is changed
		if game_bar_open then game_bar:SetPos(game_bar_x, game_bar_y)
		else game_bar:SetPos(game_bar_x, scr_h) end
	end
	
	adjust_player_visibility()
	
	--reset the lists value
	local existing_list = list.GetForEdit("DesktopWindows")
	local window_data = {
		title		= "Game Browser", --text under the icon
		icon		= "icon64/e2_game_core.png", --path to png, preferrably in icon64
		width		= browser_w,
		height		= browser_h,
		onewindow	= true, --if the window created is already opened, just recenter it instead of recreating it
		init		= open_browser --function which provides the DButton created on the desktop, it has a DImage and DLabel child, and provides the DFrame created
	}
	
	if existing_list and existing_list.WireGameCore then
		existing_list.WireGameCore = window_data
		
		--we need the context menu to update it
		CreateContextMenu()
	else list.Set("DesktopWindows", "WireGameCore", window_data) end
end

local function draw_cogs(cogs)
	local real_time = RealTime()
	
	fl_surface_SetDrawColor(color_expression)
	fl_surface_SetTexture(cog_texture)
	
	for index, cog in pairs(cogs) do fl_surface_DrawTexturedRectRotated(cog.x, cog.y, cog.size, cog.size, real_time * cog.rate + cog.offset) end
end

local function forward_response(enum)
	pop_up = nil
	
	net.Start("wire_game_core_request")
	net.WriteInt(enum, 8)
	net.WriteUInt(held_requests[1][1], 8)
	
	--remove queued requests if we accepted the request, or go to the next if we have one
	if enum > 0 then
		local send = {}
		
		if #held_requests > 1 then
			net.WriteBool(true)
			
			for index, data in pairs(held_requests) do table.insert(send, data[1]) end
			
			table.remove(send, 1)
			net.WriteTable(send)
		else net.WriteBool(false) end
		
		net.SendToServer()
		
		held_requests = {} return nil
	end
	
	net.WriteBool(false)
	net.SendToServer()
	
	--remove the request, and open the next
	table.remove(held_requests, 1)
	
	if #held_requests > 0 then open_request_gui() end
end

local function game_bar_message(new_line, ...)
	local rich_text = game_bar.rich_text
	
	if new_line then rich_text:AppendText("\n") end
	
	for index, value in ipairs({...}) do
		if type(value) == "string" then rich_text:AppendText(value)
		else rich_text:InsertColorChange(value[1], value[2], value[3], 255) end
	end
end

generate_block_form = function()
	block_form:Clear()
	block_form:Help("Uncheck the box to block a player from sending game requests to you.")
	
	button_reload = vgui.Create("DButton", block_form)
	button_reload.DoClick = generate_block_form
	
	button_reload:SetText("Regenerate List")
	
	block_form:AddItem(button_reload)
	
	for index, master in pairs(player.GetAll()) do add_block_checkbox(master) end
end

local function generate_settings_form(form)
	settings_form = form
	
	settings_form:Clear()
	settings_form:Help("Player visibility while in a game")
	settings_form:SetName("WireGameCoreSettings")
	
	player_visibility_button = vgui.Create("DButton", settings_form)
	
	player_visibility_button:SetText(game_bar_button_hide_phrases[player_visibility])
	settings_form:AddItem(player_visibility_button)
	
	function player_visibility_button:DoClick()
		player_visibility = player_visibility % 3 + 1
		
		adjust_player_visibility()
		
		game_bar.button_hide:SetText(game_bar_button_hide_phrases[player_visibility])
		self:SetText(game_bar_button_hide_phrases[player_visibility])
	end
	
	--block form, holds a check list of players
	block_form = vgui.Create("DForm", settings_form)
	
	block_form:SetName("Blocked Players")
	settings_form:AddItem(block_form)
	
	generate_block_form()
end

open_browser = function(icon, window)
	browser = window
	
	browser:SetContentAlignment(8)
	browser:SetDraggable(false)
	browser:SetSize(browser_w, browser_h)
	browser:SetTitle("Game Browser")
	
	function browser:OnClose() browser = nil end
	
	function browser:Paint(w, h)
		fl_surface_SetDrawColor(color_dark)
		fl_surface_DrawRect(0, 0, w, h)
		
		draw_cogs(game_bar_cogs)
		
		fl_surface_SetDrawColor(color_dark_header)
		fl_surface_DrawRect(0, 0, w, header)
		
		fl_surface_SetDrawColor(color_dark_track)
		fl_surface_DrawRect(0, header, w, browser_baseboard_h)
	end
	
	--the icon on the top left, clicking it will take you to the workshop page
	do
		local button_icon = vgui.Create("DButton", browser)
		
		button_icon:SetPos(margin, margin + header)
		button_icon:SetSize(browser_icon_size, browser_icon_size)
		button_icon:SetText("")
		
		function button_icon:DoClick() gui.OpenURL("https://wiki.facepunch.com/gmod/") end
		
		function button_icon:Paint(w, h)
			fl_surface_SetDrawColor(color_white)
			fl_surface_SetMaterial(browser_icon_material)
			fl_surface_DrawTexturedRect(0, 0, w, h)
		end
	end
	
	----label with info about this addon
	do
		local label_info = vgui.Create("DLabel", browser)
		
		label_info:SetContentAlignment(7)
		--label_info:SetFont("Trebuchet24")
		label_info:SetPos(browser_icon_size + margin * 2, margin + header)
		label_info:SetSize(browser_w - browser_icon_size - 3 * margin, browser_icon_size)
		label_info:SetText("View active games made with Wire Expression 2 Game Core below. Open games can be joined from here without an invite. If you'd like to create your own games with Expression 2, search up \"game\" in the E2Helper for a list of available functions. Alternatively, a list of functions will be available on the github. You can get to the github from the workshop page (the icon to the left of this text will link you to the workshop page).\n\nIf you'd like to make your game open so anyone can join it, you can use the gameSetJoinable function to do so. Alternatively, you can leave your game closed but send invites with the gameRequest function. Do note that this function has a cool down")
		label_info:SetWrap(true)
	end
	
	----scroller containing a list of games
	do
		local scroll_bar = vgui.Create("DScrollPanel", browser)
		
		scroll_bar:Dock(FILL)
		scroll_bar:DockMargin(0, browser_baseboard_h, 0, 0)
		
		--create entries, note that this can get expensive, but it will not get more expensive than O(n^2 + n)
		function scroll_bar:GenerateGameEntries()
			--todo: make it so individual entries are updated, instead of recreating this list every time a sync is received
			--if a new game appears, or players change, then we reconstruct it
			local order = {}
			
			--remove the old entries
			self:Clear()
			
			--assign a score to each game settings, and sort them into order
			local fake_game_settings = table.Merge({
				[2] = {
					open = true,
					plys = {
						[2] = true,
						[3] = true,
						[4] = true,
						[6] = true
					},
					title = "Team Fortress 3"
				},
				[3] = {
					open = false,
					plys = {
						[5] = true,
						[7] = true,
						[8] = true,
						[9] = true,
						[10] = true,
						[11] = true,
						[12] = true
					},
					title = "Cum Chalice Challenge"
				}
			}, table.Copy(game_settings))
			
			--determine "scores" for each game, higher score means higher placement in the list
			for master_index, settings in pairs(fake_game_settings) do
				local achieved = 0
				local chosen_index = #order + 1
				
				if settings.open then achieved = table.Count(settings.plys) + 257
				else achieved = table.Count(settings.plys) + 1 end
				
				for index, data in ipairs(order) do
					if achieved > data[2] then
						--we found a spot which they fit, put them in it
						chosen_index = index
						
						break
					end
				end
				
				table.insert(order, chosen_index, {master_index, achieved, settings.title, settings.open})
			end
			
			--create the entries in the order determined
			for _, data in ipairs(order) do
				local button = vgui.Create("DButton", self)
				local button_layout = button.PerformLayout
				local master_index = data[1]
				
				--we need the entity to get name n stuff
				local master = Entity(master_index)
				local master_valid = IsValid(master)
				
				self:AddItem(button)
				
				button:Dock(TOP)
				button:DockMargin(margin, margin, margin, 0)
				button:SetText(data[2] .. " - " .. data[3])
				button:SetHeight(browser_button_h)
				
				button.Paint = button_paint
				
				----player's avatar
					local avatar = vgui.Create("AvatarImage", button)
					
					avatar:Dock(LEFT)
					avatar:DockMargin(4, 4, 0, 20)
					avatar:InvalidateLayout(true)
					
					if master_valid then avatar:SetPlayer(master, 184) end
				
				----player name
					local label_host = vgui.Create("DLabel", button)
					
					label_host:SetContentAlignment(5)
					label_host:SetText(master_valid and master:Nick() or "Invalid")
					label_host:SetTextColor(color_dark_text)
				
				--make it so players can join the game if it's open
				if data[4] then
					function button:DoClick()
						net.Start("wire_game_core_join")
						net.WriteInt(master_index, 8)
						net.SendToServer()
						
						browser:Close()
					end
				else
					button:SetCursor("none")
					button:SetEnabled(false)
				end
				
				--properly size stuff
				function button:PerformLayout(w, h)
					local avatar_size = h - 24
					
					avatar:SetWidth(h - 24) --24 is top margin + bottom margin
					
					label_host:SetPos(4, h - 20) --bottom margin of avatar
					label_host:SetSize(avatar_size, 20)
				end
			end
		end
		
		--now call that function we made
		scroll_bar:GenerateGameEntries()
		
		--give us access for later :)
		browser.scroll_bar = scroll_bar
	end
end

open_request_gui = function()
	held_requests[1][2] = CurTime() + pop_up_duration
	pop_up = vgui.Create("DFrame", nil, "WireGameCoreRequest")
	
	local pop_up_layout = pop_up.PerformLayout
	local requester_index = held_requests[1][1]
	local requester_name = Entity(requester_index):Nick()
	
	pop_up:SetTitle("Game request from " .. requester_name)
	pop_up:SetSize(pop_up_w, pop_up_h)
	
	--we won't need the minimize button, but we'll keep the maximize and close to repurpose them
	pop_up.btnMinim:SetVisible(false)
	
	--close and deny button, reuses the close button
	----we can't put it in a do end block because the deny button needs this DoClick function, and that would mean accessing a value in a different scope
		local button_close = pop_up.btnClose
		
		button_close:SetText("Deny")
		button_close:SetTextColor(color_white)
		
		function button_close:DoClick()
			pop_up:Remove()
			forward_response(-1)
		end
		
		function button_close:Paint(w, h)
			if self.Depressed or self:IsSelected() or self:GetToggle() then fl_surface_SetDrawColor(color_expression) 
			elseif self.Hovered then fl_surface_SetDrawColor(color_dark_baseboard)
			else fl_surface_SetDrawColor(color_dark_button) end
			
			fl_surface_DrawRect(0, 2, w, h - 4)
		end
	
	----block button, reuses the maximize button
	do
		local button_block = pop_up.btnMaxim
		
		button_block:SetEnabled(true)
		button_block:SetFont("DermaDefaultBold")
		button_block:SetText("BLOCK")
		button_block:SetTextColor(color_white)
		
		function button_block:DoClick()
			game_blocks[requester_index] = true
			
			if block_form then game_blocks_check_boxes[requester_index]:SetChecked(false) end
			
			pop_up:Remove()
			forward_response(-3)
		end
		
		function button_block:Paint(w, h)
			if self.Depressed or self:IsSelected() or self:GetToggle() then fl_surface_SetDrawColor(color_expression) 
			elseif self.Hovered then fl_surface_SetDrawColor(color_expression_excited)
			else fl_surface_SetDrawColor(color_expression) end
			
			fl_surface_DrawRect(0, 2, w, h - 4)
		end
	end
	
	----accept button
	do
		local button_accept = vgui.Create("DButton", pop_up)
		
		button_accept:SetPos(margin, pop_up_button_accept_y)
		button_accept:SetSize(pop_up_button_accept_w, pop_up_button_accept_h)
		button_accept:SetText("Accept")
		button_accept:SetTextColor(color_white)
		
		button_accept.Paint = button_paint
		
		function button_accept:DoClick()
			pop_up:Remove()
			forward_response(1)
		end
	end
	
	----deny button
	do
		local button_deny = vgui.Create("DButton", pop_up)
		
		button_deny:SetPos(pop_up_button_deny_x, pop_up_button_accept_y)
		button_deny:SetSize(pop_up_button_accept_w, pop_up_button_accept_h)
		button_deny:SetText("Deny")
		button_deny:SetTextColor(color_white)
		
		button_deny.DoClick = button_close.DoClick
		button_deny.Paint = button_paint
	end
	
	----info box
	do
		local panel_info = vgui.Create("DPanel", pop_up)
		local panel_info_text = requester_name .. " has invited you to join their game.\n\nAccepting will grant them more access with Expression 2,\nbut you can revoke their access at anytime by using the context menu."
		
		panel_info:SetPos(margin, pop_up_panel_info_y)
		panel_info:SetSize(pop_up_panel_info_w, pop_up_panel_info_h)
		
		function panel_info:Paint(w, h)
			--todo: optimize
			local time_left = math.ceil(held_requests[1][2] - CurTime())
			
			draw.DrawText(panel_info_text .. "\n\nThis invite expires in " .. time_left .. (time_left == 1 and " second." or " seconds."), "DermaDefault", w * 0.5, margin, color_white, TEXT_ALIGN_CENTER)
		end
	end
	
	function pop_up:Paint(w, h)
		fl_surface_SetDrawColor(color_dark)
		fl_surface_DrawRect(0, 0, w, h)
		
		draw_cogs(pop_up_cogs)
		
		fl_surface_SetDrawColor(color_dark_header)
		fl_surface_DrawRect(0, 0, w, header)
		
		fl_surface_SetDrawColor(color_dark_baseboard)
		fl_surface_DrawRect(0, pop_up_baseboard_y, w, pop_up_baseboard_h)
	end
	
	--we have to modify the close and maxim buttons here, as they are changed in this function
	function pop_up:PerformLayout(w, h)
		pop_up_layout(self)
		
		self.btnClose:SetPos(w - 52, 0)
		self.btnClose:SetWide(48, 24)
		
		self.btnMaxim:SetPos(w - 104, 0)
		self.btnMaxim:SetSize(48, 24)
	end
	
	pop_up:Center()
	pop_up:MakePopup()
end

local function request_full_sync()
	net.Start("wire_game_core_sync")
	net.SendToServer()
end

local function show_game_bar(state, finish)
	print("show_game_bar ran", state, finish)
	debug.Trace()
	
	if game_bar_animating then
		me:PrintMessage(HUD_PRINTTALK, "game bar was animating, returning", state)
		
		return
	end
	
	if state then
		print("show")
		
		if not game_bar_open then
			--open
			game_bar_animating = true
			game_bar_open = true
			
			print("show passed")
			
			local game_bar_animation = game_bar:NewAnimation(game_bar_animation_duration, 0, game_bar_animation_curve, function()
				print("show finish")
				
				game_bar_animating = false
				
				game_bar:SetPos(game_bar_x, game_bar_y)
				
				if not game_bar_desired or not game_master_index then show_game_bar(false) end
				if finish then finish() end
			end)
			
			function game_bar_animation:Think(panel, fraction)
				print("show animating")
				
				game_bar:SetPos(game_bar_x, scr_h - fraction * game_bar_h)
			end
		else print("game bar was open, not opening") end
	else
		print("hide")
		
		if game_bar_open then
			--close
			game_bar_animating = true
			game_bar_open = false
			
			local game_bar_animation = game_bar:NewAnimation(game_bar_animation_duration, 0, game_bar_animation_curve, function()
				game_bar_animating = false
				
				game_bar:SetPos(game_bar_x, scr_h)
				
				if finish then finish() end
				if game_bar_desired then show_game_bar(true) end
			end)
			
			function game_bar_animation:Think(panel, fraction) game_bar:SetPos(game_bar_x, game_bar_y + fraction * game_bar_h) end
		else print("game bar wasn't open, not closing") end
	end
end

local function update_game_bar()
	game_bar.label_title:SetText(game_settings[game_master_index].title)
	game_bar.label_master:SetText("Hosted by " .. game_master:Nick())
end

--post function setup
calc_vars()

--concommand
concommand.Add("wire_game_core_reload", function()
	--this stuff is also being used for autoreload, but is safe to run anyways
	local hooks = hook.GetTable()
	local world_panel = vgui.GetWorldPanel()
	
	local found_context_menu = world_panel:Find("ContextMenu")
	local found_game_bar = world_panel:Find("WireGameCoreGameBar")
	local found_pop_up = world_panel:Find("WireGameCoreRequest")
	
	if found_game_bar then found_game_bar:Remove() end
	if found_pop_up then found_pop_up:Remove() end
	
	hooks.ContextMenuCreated.wire_game_core(found_context_menu) --my old method, but now we have to recreate it when working with desktop icons
	hooks.InitPostEntity.wire_game_core()
end, nil, "Debug for game core, will be removed,")

concommand.Add("wire_game_core_debug_cogs", function()
	local frame = vgui.Create("DFrame")
	
	frame:SetSize(800, 800)
	frame:SetTitle("Cog Debugger")
	
	local cog_panel = vgui.Create("DPanel", frame)
	
	cog_panel:Dock(FILL)
	cog_panel:DockMargin(4, 4, 4, 4)
	
	function cog_panel:Paint(w, h)
		fl_surface_SetDrawColor(color_dark)
		fl_surface_DrawRect(0, 0, w, h)
		
		draw_cogs(pop_up_cogs)
	end
	
	frame:Center()
	frame:MakePopup()
end, nil, "Debug for game core, used to debug the cog algorithm.")

concommand.Add("wire_game_core_debug_rich", function(ply, command, args, text)
	if game_master and game_bar then
		local rich_text = game_bar.rich_text
		
		rich_text:AppendText("\n" .. text)
	end
end, nil, "Debug for game core, used to debug the cog algorithm.")

--cvars
cvars.AddChangeCallback("wire_game_core_request_duration", function() pop_up_duration = wire_game_core_request_duration:GetFloat() end)

--hooks
hook.Add("CanArmDupe", "wire_game_core", active_game_inv)
hook.Add("CanDrive", "wire_game_core", active_game_inv)
hook.Add("CanProperty", "wire_game_core", active_game_inv)
hook.Add("CanTool", "wire_game_core", active_game_inv)

hook.Add("ContextMenuCreated", "wire_game_core", function(panel)
	context_menu = panel
	game_bar = vgui.Create("EditablePanel", GetHUDPanel(), "WireGameCoreGameBar")
	--RichText
	game_bar:SetMouseInputEnabled(true)
	game_bar:SetPos(game_bar_x, scr_h)
	game_bar:SetSize(game_bar_w, game_bar_h)
	
	function game_bar:Paint(w, h)
		fl_surface_SetDrawColor(color_dark)
		fl_surface_DrawRect(0, 0, w, h)
		
		draw_cogs(game_bar_cogs)
		
		fl_surface_SetDrawColor(color_dark_header)
		fl_surface_DrawRect(0, 0, w, game_bar_header)
	end
	
	----label showing the game title
	do
		local label_title = vgui.Create("DLabel", game_bar)
		
		label_title:Dock(TOP)
		label_title:SetContentAlignment(5)
		label_title:SetFont("CreditsText")
		label_title:SetHeight(game_bar_header * 0.6)
		label_title:SetText("Unknown Game")
		
		game_bar.label_title = label_title
	end
	
	----label showing the host
	do
		local label_master = vgui.Create("DLabel", game_bar)
		
		label_master:Dock(TOP)
		label_master:SetColor(color_dark_text)
		label_master:SetContentAlignment(5)
		label_master:SetHeight(game_bar_header * 0.4)
		label_master:SetText("Unknown Host")
		
		game_bar.label_master = label_master
	end
	
	----rich text for the owner to give updates
	do
		local rich_text = vgui.Create("RichText", game_bar)
		local rich_text_track = rich_text:Find("ScrollBar")
		
		rich_text:SetPos(game_bar_sidebar_w + margin, game_bar_header + margin)
		rich_text:SetSize(game_bar_w - game_bar_sidebar_w - margin_double, game_bar_sidebar_h - margin_double)
		
		function rich_text:PerformLayout()
			rich_text:SetBGColorEx(28, 28, 28, 192)
			rich_text:SetFontInternal("DermaDefault")
			
			for index, child in pairs(rich_text_track:GetChildren()) do child:SetVisible(false) end
		end
		
		game_bar.rich_text = rich_text
	end
	
	----scroll bar holding some buttons
		local scroll_bar = vgui.Create("DScrollPanel", game_bar)
		local scroll_bar_buttons = {}
		local scroll_bar_track = scroll_bar:GetVBar()
		
		scroll_bar:SetPos(0, game_bar_header)
		scroll_bar:SetSize(game_bar_sidebar_w, game_bar_sidebar_h)
		scroll_bar_track:SetHideButtons(true)
		
		function scroll_bar:Paint(w, h)
			fl_surface_SetDrawColor(color_dark_baseboard)
			fl_surface_DrawRect(0, 0, w, h)
		end
		
		function scroll_bar_track:Paint(w, h)
			fl_surface_SetDrawColor(color_dark_track)
			fl_surface_DrawRect(0, 0, w, h)
		end
		
		function scroll_bar_track.btnGrip:Paint(w, h)
			if self.Depressed then fl_surface_SetDrawColor(color_expression)
			elseif self.Hovered then fl_surface_SetDrawColor(color_dark_button_hover)
			else fl_surface_SetDrawColor(color_dark_button) end
			
			fl_surface_DrawRect(0, 0, w, h)
		end
	
	----button to leave the game
	do
		local button_leave = vgui.Create("DButton", game_bar)
		
		button_leave:SetText("Leave Game")
		button_leave:SetTextColor(color_button_text)
		
		function button_leave:DoClick()
			--idontwannaplayheavyanymore
			net.Start("wire_game_core_leave")
			net.SendToServer()
		end
		
		table.insert(scroll_bar_buttons, button_leave)
	end
	
	----button to hide players
	do
		local button_hide = vgui.Create("DButton", game_bar)
		
		button_hide:SetText(game_bar_button_hide_phrases[player_visibility])
		button_hide:SetTextColor(color_button_text)
		
		function button_hide:DoClick()
			player_visibility = player_visibility % 3 + 1
			
			adjust_player_visibility()
			
			if player_visibility_button then player_visibility_button:SetText(game_bar_button_hide_phrases[player_visibility]) end
			
			self:SetText(game_bar_button_hide_phrases[player_visibility])
		end
		
		game_bar.button_hide = button_hide
		
		table.insert(scroll_bar_buttons, button_hide)
	end
	
	----button to do something
	do
		local button_undecided = vgui.Create("DButton", game_bar)
		
		button_undecided:SetText("Undecided")
		button_undecided:SetTextColor(color_button_text)
		
		function button_undecided:DoClick()
			self:SetText("FUCK YOU")
			
			timer.Remove("wire_game_core_button_undecided")
			timer.Create("wire_game_core_button_undecided", 1, 0, function() if IsValid(self) then self:SetText("Undecided") end end)
		end
		
		table.insert(scroll_bar_buttons, button_undecided)
	end
	
	--add buttons to the sidebar
	for index, button in ipairs(scroll_bar_buttons) do
		scroll_bar:AddItem(button)
		
		button:Dock(TOP)
		button:DockMargin(margin, margin, margin, 0)
		
		button.Paint = button_paint
	end
end)

hook.Add("InitPostEntity", "wire_game_core", function()
	me = LocalPlayer()
	me_index = me:EntIndex()
	
	request_full_sync()
	
	local distance_alpha_max_alpha = 16
	local distance_alpha_max_distance = 512
	local distance_alpha_min_distance = 128
	
	local distance_alpha_diff = distance_alpha_max_distance - distance_alpha_min_distance
	
	hook.Add("PostDrawTranslucentRenderables", "wire_game_core", function(ply)
		--we should instead drop this into the InitPostEntity hook but that'd stop autoreload for doing its bussiness
		local view_entity = GetViewEntity()
		
		for index, ply in pairs(player.GetAll()) do
			if game_masters[ply:EntIndex()] then
				if IsValid(ply) and ply:Alive() then
					--I know this is expensive, but how else can I get a linear fading alpha
					local distance = ply:GetPos():Distance(view_entity:GetPos())
					
					if distance < distance_alpha_max_distance then
						local distance_alpha = math.Clamp((distance - distance_alpha_max_distance) / -distance_alpha_diff, 0, 1) * distance_alpha_max_alpha
						local weapon = ply:GetActiveWeapon()
						
						color_game_highlight.a = distance_alpha
						
						fl_render_ClearStencil()
						fl_render_SetStencilEnable(true)
						fl_render_SetStencilCompareFunction(STENCIL_ALWAYS)
						fl_render_SetStencilPassOperation(STENCIL_REPLACE)
						fl_render_SetStencilFailOperation(STENCIL_KEEP)
						fl_render_SetStencilZFailOperation(STENCIL_KEEP)
						fl_render_SetStencilWriteMask(0xFF)
						fl_render_SetStencilTestMask(0xFF)
						fl_render_SetStencilReferenceValue(1)
						
						ply:DrawModel()
						
						if IsValid(weapon) then weapon:DrawModel() end
						
						--draw a colored rectangle over the screen where the stencil value matches 1
						fl_render_SetStencilCompareFunction(STENCIL_EQUAL)
						fl_cam_Start2D()
							fl_surface_SetDrawColor(color_game_highlight)
							fl_surface_DrawRect(0, 0, scr_w, scr_h)
						fl_cam_End2D()
						fl_render_SetStencilEnable(false)
					end
				end
			end
		end
	end)
	
	hook.Add("Think", "wire_game_core", function()
		local alive = me:Alive()
		local cur_time = CurTime()
		local new_requests = {}
		
		--[[if alive ~= last_alive then
			--show the bar while they are dead >:D
			game_bar_desired = last_alive
			last_alive = alive
		end]] --needs testing
		
		for index, data in ipairs(held_requests) do
			--can't use table.remove or it skips over indices
			--1: master index, 2: expiration time, 3: marked for removal
			local master_index = data[1]
			
			if cur_time < data[2] and not data[3] then table.insert(new_requests, data)
			elseif index == 1 and pop_up then
				pop_up:Remove()
				forward_response(-2)
			end
		end
		
		held_requests = new_requests
	end)
end)

hook.Add("OnContextMenuClose", "wire_game_core", function()
	game_bar_desired = false
	
	game_bar:SetParent(GetHUDPanel())
	game_bar:SetMouseInputEnabled(false)
	
	if game_master_index then
		--
		show_game_bar(false)
	end
end)

hook.Add("OnContextMenuOpen", "wire_game_core", function()
	game_bar_desired = true
	
	game_bar:SetParent(context_menu)
	game_bar:SetMouseInputEnabled(true)
	
	timer.Remove("wire_game_core_game_bar_close")
	
	if game_master_index then show_game_bar(true) end
end)

hook.Add("OnScreenSizeChanged", "wire_game_core", calc_vars)
hook.Add("PlayerNoClip", "wire_game_core", function(ply, desire) if game_masters[ply:EntIndex()] and desire then return false end end)
hook.Add("PopulateToolMenu", "wire_game_core", function() spawnmenu.AddToolMenuOption("Utilities", "User", "WireGameCore", "E2 Game Core", "", "", generate_settings_form) end)

--not yet, I still want to test
--hook.Add("SpawnMenuOpen", "wire_game_core", function() if game_master_index then return false end end)

hook.Add("ShouldCollide", "wire_game_core", function(ent_1, ent_2)
	if ent_1:IsPlayer() and ent_2:IsPlayer() and game_masters[ent_1:EntIndex()] ~= game_masters[ent_2:EntIndex()] then return false end
	
	return true
end)

--net
net.Receive("wire_game_core_block", function()
	game_blocks = net.ReadTable()
	
	timer.Remove("wire_game_core_block_form_timeout")
	
	--update the check boxes
	--we do it like this instead of recreating the check boxes because we are perfectionists and don't want the form's animation to play
	for master_index, panel in pairs(game_blocks_check_boxes) do
		panel:SetEnabled(true)
		
		if game_blocks[master_index] then panel:SetChecked(false) end
	end
end)

net.Receive("wire_game_core_block_update", function()
	--we need this because player connect hooks and gameevents don't work consistently client side
	if block_form then
		local new_ply = net.ReadBool()
		local ply_index = net.ReadUInt(8)
		
		if new_ply then add_block_checkbox(Entity(ply_index))
		else game_blocks_check_boxes[ply_index]:Remove() end
	end
end)

net.Receive("wire_game_core_join", function()
	game_bar_desired = true
	game_master_index = net.ReadUInt(8)
	game_master = Entity(game_master_index)
	local rich_text = game_bar.rich_text
	
	--reading when nothing is there scares me, so lets check
	if net.ReadBool() then weapon_class = net.ReadString() end
	
	--let's cache the player so we don't have to keep fetching them
	
	rich_text:SetText("")
	
	adjust_player_visibility()
	game_bar_message(false, {255, 255, 128}, "You joined " .. game_master:Nick() .. "'s game.")
	show_game_bar(true, function()
		timer.Create("wire_game_core_game_bar_close", 5, 1, function()
			--short timers are okay by my standard
			game_bar_desired = false
			
			show_game_bar(false)
		end)
	end)
end)

net.Receive("wire_game_core_leave", function()
	show_game_bar(false)
	
	game_bar_desired = false
	
	if weapon_class then
		local weapon = me:GetWeapon(weapon_class)
		
		--it's fine to do SelectWeapon like this, I swear
		--no, its not
		timer.Simple(0, function() if IsValid(weapon) then input.SelectWeapon(weapon) end end)
		
		game_master = nil
		game_master_index = nil
		weapon_class = nil
	end
	
	adjust_player_visibility(1)
end)

net.Receive("wire_game_core_masters", function()
	game_masters = table.Merge(game_masters, net.ReadTable())
	
	for ply_index, master_index in pairs(game_masters) do
		local ply = Entity(ply_index)
		
		if master_index == 0 then
			game_masters[ply_index] = nil
			
			ply:SetCustomCollisionCheck(false)
		else ply:SetCustomCollisionCheck(true) end
		
		ply:CollisionRulesChanged()
	end
end)

net.Receive("wire_game_core_request", function()
	local requests = net.ReadTable()[me_index]
	
	if requests then
		local cur_time = CurTime()
		
		--refresh times and remove the index from the requests we received if we did
		for index, data in pairs(held_requests) do
			local master_index = data[1]
			
			if requests[master_index] then
				held_requests[index][2] = cur_time + pop_up_duration
				requests[master_index] = nil
			end
		end
		
		--add the new requests to the request queue
		for master_index in pairs(requests) do table.insert(held_requests, {master_index, cur_time + pop_up_duration}) end
		
		--if they don't have a request open, open the gui
		if not pop_up then open_request_gui() end
	end
end)

net.Receive("wire_game_core_sounds", function()
	local sounds = net.ReadTable()
	
	for index, sound_path in pairs(sounds) do surface.PlaySound(sound_path) end
end)

net.Receive("wire_game_core_sync", function()
	local received_settings = net.ReadTable()
	
	--not sufficient! we have yet to cull unchanged information, so we need to set the table's index
	--table.Merge(game_settings, received_settings)
	
	for master_index, settings in pairs(received_settings) do 
		if settings == false then game_settings[master_index] = nil
		else game_settings[master_index] = settings end
	end
	
	if held_requests[1] then
		local cur_time = CurTime()
		
		--make all requests for closing games expire
		for index, data in ipairs(held_requests) do if not game_settings[data[1]] then held_requests[index][3] = true end end
	end
	
	if IsValid(browser) then browser.scroll_bar:GenerateGameEntries() end
	if game_master_index and received_settings[game_master_index] then update_game_bar() end
end)

--auto reload, will be removed in the future
if WireGameCore then RunConsoleCommand("wire_game_core_reload")
else WireGameCore = true end