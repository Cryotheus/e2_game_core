--note that I am still working on this, so I have not yet cached rendering functions and there is some other stuff which probably needs to be optimized
--tables
local game_blocks = {}				--y stores the blocked players, may not be used;	k: master index,		v: true
local game_blocks_check_boxes = {}	--y stores the checkbox panel for every player;		k: master index,		v: panel
local game_collidables = {}			--y
local game_masters = {}				--y used to fetch the player's game master;			k: player index,		v: master index
local game_settings = {}			--y stores the settings for each players game;		k: master index,		v: table where (k: setting name, v: setting value)
local held_requests = {}			--y stores requests the player has received;		k: sequential index,	v: table where (k: setting num, v: setting data)
local player_physgun_colors = {}	--y stores the color of the player's physgun;		k: player index,		v: color
local player_visibility = 1

local context_menu_open = false
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
	local associated_colors = include("wire_game_core/includes/colors.lua")
	local color_button_text = associated_colors.color_button_text
	local color_dark = associated_colors.color_dark
	local color_dark_baseboard = associated_colors.color_dark_baseboard
	local color_dark_button = associated_colors.color_dark_button
	local color_dark_button_hover = associated_colors.color_dark_button_hover
	local color_dark_header = associated_colors.color_dark_header
	local color_dark_text = associated_colors.color_dark_text
	local color_dark_track = associated_colors.color_dark_track
	local color_expression = associated_colors.color_expression
	local color_expression_excited = associated_colors.color_expression_excited
	local color_game_highlight = associated_colors.color_game_highlight
	local color_game_indicator = associated_colors.color_game_indicator
	local color_ghost = associated_colors.color_ghost

----render parameters
	local block_form
	local button_reload
	local browser
	local browser_baseboard_h
	local browser_button_h
	local browser_cogs = {}
	local browser_cogs_2 = {}
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
	local game_bar_animation_curve = math.pi * 0.5
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
	local game_bar_sidebar_h
	local game_bar_sidebar_w
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

local tags = include("wire_game_core/includes/tags.lua")

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
	local translate = include("wire_game_core/includes/translate.lua")

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

local function button_paint_close(self, w, h)
	if self.Depressed or self:IsSelected() or self:GetToggle() then fl_surface_SetDrawColor(color_expression) 
	elseif self.Hovered then fl_surface_SetDrawColor(color_dark_baseboard)
	else fl_surface_SetDrawColor(color_dark_button) end
	
	fl_surface_DrawRect(0, 2, w, h - 4)
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
	
	--what
	
	browser_cogs = calc_cogs(10, 1, 0, 0, {
		{
			angle = 45,
			offset = 6.25,
			size = 2
		},
		{
			angle = 30,
			offset = 0,
			size = 1
		},
		{
			angle = -60,
			offset = 3.5,
			size = 1
		},
		{
			angle = -60,
			offset = 6.25,
			size = 0.5
		},
		{
			angle = -60,
			offset = 2.5,
			size = 1
		},
		{
			angle = 30,
			offset = 2.5,
			size = 1
		},
		{
			angle = 100,
			offset = 1.125,
			size = 2
		},
		{
			angle = 90,
			offset = 2.75,
			size = 1
		},
		{
			angle = 0,
			offset = 0,
			size = 0.5
		},
		{
			angle = 10,
			offset = 2.5,
			size = 1.5
		},
		{
			angle = 90,
			offset = -0.5,
			size = 0.5
		},
		{
			angle = -45,
			offset = -1,
			size = 1
		},
		{
			angle = -90,
			offset = 10.5,
			size = 1
		},
		{
			angle = 90,
			offset = -1,
			size = 0.5
		},
		{
			angle = 70,
			offset = 7.25,
			size = 1
		},
	})
	
	browser_cogs_2 = calc_cogs(5, 2, 900, 700, {
		{
			angle = 45,
			offset = 12.5, --revelation 1: smaller gear has larger offset
			size = 1
		},
		{
			angle = -90,
			offset = 12.5 * 0,
			size = 1
		},
		{
			angle = -45,
			offset = 12.5,
			size = 1
		},
		{
			angle = 15,
			offset = -0.25,
			size = 2
		},
		{
			angle = 60,
			offset = 12.25,
			size = 1
		},
		{
			angle = 90,
			offset = 7,
			size = 1
		},
		{
			angle = 30,
			offset = 2.25,
			size = 2
		},
		{
			angle = 15,
			offset = 7.5,
			size = 1
		},
	})
	
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
	
	if game_bar then
		--reposition the bar if it exists, I only imagine this happening if the screen resolution is changed
		if game_bar.Active then game_bar:SetPos(game_bar_x, game_bar_y)
		else game_bar:SetPos(game_bar_x, scr_h) end
	end
	
	adjust_player_visibility()
	
	--reset the lists value
	local existing_list = list.GetForEdit("DesktopWindows")
	local window_data = {
		title		= "#wire_game_core.browser.title", --text under the icon
		icon		= "icon64/game_core_browser_icon.png", --path to png, preferrably in icon64
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

local function game_bar_message(new_line, message_table)
	local rich_text = game_bar.rich_text
	
	if new_line then rich_text:AppendText("\n") end
	
	for index, value in ipairs(message_table) do
		if isstring(value) then rich_text:AppendText(value)
		else rich_text:InsertColorChange(value[1], value[2], value[3], value[4] or 255) end
	end
end

local function game_bar_message_ez(new_line, ...) game_bar_message(new_line, {...}) end

generate_block_form = function()
	block_form:Clear()
	block_form:Help("#wire_game_core.settings.blocker.info")
	
	button_reload = vgui.Create("DButton", block_form)
	button_reload.DoClick = generate_block_form
	
	button_reload:SetText("#wire_game_core.settings.blocker.reload")
	
	block_form:AddItem(button_reload)
	
	for index, master in pairs(player.GetAll()) do add_block_checkbox(master) end
end

local function generate_settings_form(form)
	settings_form = form
	
	settings_form:Clear()
	settings_form:Help("#wire_game_core.settings.visibility")
	settings_form:SetName("WireGameCoreSettings")
	
	player_visibility_button = vgui.Create("DButton", settings_form)
	
	player_visibility_button:SetText("#wire_game_core.settings.visibility." .. player_visibility)
	settings_form:AddItem(player_visibility_button)
	
	function player_visibility_button:DoClick()
		player_visibility = player_visibility % 3 + 1
		
		adjust_player_visibility()
		
		game_bar.button_hide:SetText("#wire_game_core.settings.visibility." .. player_visibility)
		self:SetText("#wire_game_core.settings.visibility." .. player_visibility)
	end
	
	--block form, holds a check list of players
	block_form = vgui.Create("DForm", settings_form)
	
	block_form:SetName("#wire_game_core.settings.blocker.title")
	settings_form:AddItem(block_form)
	
	generate_block_form()
end

local function get_owner_contextless(entity)
	if entity.GetPlayer then
		local ply = entity:GetPlayer()
		
		if IsValid(ply) then return ply end
	end
	
	local on_die_functions = entity.OnDieFunctions
	
	if on_die_functions then
		local get_count_update = on_die_functions.GetCountUpdate
		
		if get_count_update and get_count_update.Args and get_count_update.Args[1] then return get_count_update.Args[1] end
		if on_die_functions.undo1 and on_die_functions.undo1.Args and on_die_functions.undo1.Args[2] then return on_die_functions.undo1.Args[2] end
	end
	
	if entity.GetOwner then
		local ply = entity:GetOwner()
		
		if IsValid(ply) then return ply end
	end
end

open_browser = function(icon, window)
	----browser
		--why does it layout every frame?
		--weird as fuck
		browser = window
		local game_entry_container
		local panel_cogs
		
		browser:SetContentAlignment(8)
		browser:SetDraggable(true)
		browser:SetMinimumSize(browser_w * 0.5, browser_h * 0.5)
		browser:SetSizable(true)
		browser:SetSize(browser_w, browser_h)
		browser:SetTitle("#wire_game_core.browser.title")
		
		browser.btnMaxim:SetVisible(false)
		browser.btnMinim:SetVisible(false)
			
		function browser:OnRemove() browser = nil end
		
		function browser:Paint(w, h)
			fl_surface_SetDrawColor(color_dark)
			fl_surface_DrawRect(0, 0, w, h)
			
			fl_surface_SetDrawColor(color_dark_header)
			fl_surface_DrawRect(0, 0, w, header)
			
			fl_surface_SetDrawColor(color_dark_track)
			fl_surface_DrawRect(0, header, w, browser_baseboard_h)
		end
		
		do --close button
			local button_close = browser.btnClose
			
			button_close:SetText("#wire_game_core.browser.close")
			
			button_close.Paint = button_paint_close
			
			function browser.btnClose:PerformLayout(width, height)
				surface.SetFont("DermaDefault")
				
				local text_width = surface.GetTextSize(language.GetPhrase("wire_game_core.browser.close"))
				local size = text_width + 10
				
				self:SetPos(self:GetParent():GetWide() - size - 2, 0)
				self:SetWidth(size)
			end
		end
	
	do --the icon on the top left, clicking it will take you to the workshop page
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
	
	do --label with info about this addon
		local label_info = vgui.Create("DLabel", browser)
		
		label_info:Dock(FILL)
		label_info:DockMargin(browser_icon_size + margin * 2, margin, margin, margin)
		label_info:SetContentAlignment(7)
		label_info:SetText("#wire_game_core.browser.info")
		label_info:SetWrap(true)
	end
	
	do --game entry container
		game_entry_container = vgui.Create("WGCBrowserGameEntryContainer", browser)
		
		game_entry_container.FrameBrowser = browser
		game_entry_container.GameEntryHeaders = {}
		
		game_entry_container:Dock(FILL)
		game_entry_container:DockMargin(0, browser_baseboard_h - 5, 0, 0)
		
		for master_index, settings in pairs(game_settings) do
			local game_entry = game_entry_container:AddEntry(master_index, settings)
			
			game_entry_container.GameEntryHeaders[master_index] = game_entry.Header
		end
		
		browser.GameEntryContainer = game_entry_container
	end
	
	do --panel for fancy graphics
		--we does this weird bullshit so we don't have to do weird hook bullshit
		panel_cogs = vgui.Create("DPanel", browser)
		
		panel_cogs:Dock(FILL)
		panel_cogs:SetKeyBoardInputEnabled(false)
		panel_cogs:SetMouseInputEnabled(false)
		panel_cogs:SetZPos(1)
		
		--TODO: cache these functions!
		function panel_cogs:Paint(width, height)
			render.ClearStencil()
			render.SetStencilCompareFunction(STENCIL_NEVER)
			render.SetStencilEnable(true)
			render.SetStencilFailOperation(STENCIL_REPLACE)
			render.SetStencilPassOperation(STENCIL_KEEP)
			render.SetStencilReferenceValue(1)
			render.SetStencilTestMask(0xFF)
			render.SetStencilWriteMask(0xFF)
			render.SetStencilZFailOperation(STENCIL_KEEP)
			
			for master_index, header in pairs(game_entry_container.GameEntryHeaders) do
				local x, y = self:ScreenToLocal(header:LocalToScreen())
				
				fl_surface_SetDrawColor(255, 255, 255)
				fl_surface_DrawRect(x, y, header:GetSize())
			end
			
			render.SetStencilFailOperation(STENCIL_INCR)
			render.SetStencilPassOperation(STENCIL_KEEP)
			
			fl_surface_SetDrawColor(255, 255, 255, 32)
			fl_surface_DrawRect(game_entry_container:GetBounds())
			
			render.SetStencilReferenceValue(2)
			render.SetStencilCompareFunction(STENCIL_EQUAL)
			render.SetStencilFailOperation(STENCIL_KEEP)
			render.SetStencilPassOperation(STENCIL_REPLACE)
			
			draw_cogs(browser_cogs)
			draw_cogs(browser_cogs_2)
			
			for master_index, header in pairs(game_entry_container.GameEntryHeaders) do header:PaintManual() end
			
			render.SetStencilEnable(false)
		end
		
		function panel_cogs:PerformLayout(width, height)
			self:SetPos(0, 0)
			self:SetSize(browser:GetSize())
		end
	end
end

open_request_gui = function()
	held_requests[1][2] = CurTime() + pop_up_duration
	pop_up = vgui.Create("DFrame", nil, "WireGameCoreRequest")
	
	local pop_up_layout = pop_up.PerformLayout
	local requester_index = held_requests[1][1]
	local requester_name = Entity(requester_index):Nick()
	
	pop_up:SetTitle(translate("wire_game_core.request.title", {name = requester_name}))
	pop_up:SetSize(pop_up_w, pop_up_h)
	
	--we won't need the minimize button, but we'll keep the maximize and close buttons because we repurpose them
	pop_up.btnMinim:SetVisible(false)
	
	--close and deny button, reuses the close button
	----we can't put it in a do end block because the deny button needs this DoClick function, and that would mean accessing a value in a different scope
		local button_close = pop_up.btnClose
		button_close.Paint = button_paint_close
		
		button_close:SetText("#wire_game_core.request.deny")
		button_close:SetTextColor(color_white)
		
		function button_close:DoClick()
			pop_up:Remove()
			forward_response(-1)
		end
	
	----block button, reuses the maximize button
	do
		local button_block = pop_up.btnMaxim
		
		button_block:SetEnabled(true)
		button_block:SetFont("DermaDefaultBold")
		button_block:SetText("#wire_game_core.request.block")
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
		button_accept:SetText("#wire_game_core.request.accept")
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
		button_deny:SetText("#wire_game_core.request.deny")
		button_deny:SetTextColor(color_white)
		
		button_deny.DoClick = button_close.DoClick
		button_deny.Paint = button_paint
	end
	
	----info box
	do
		local panel_info = vgui.Create("DPanel", pop_up)
		local panel_info_text
		
		panel_info:SetPos(margin, pop_up_panel_info_y)
		panel_info:SetSize(pop_up_panel_info_w, pop_up_panel_info_h)
		
		function panel_info:Paint(w, h)
			local time_left = math.ceil(held_requests[1][2] - CurTime())
			
			if self.TimeLeft ~= time_left then
				panel_info_text = translate("wire_game_core.request.info", {
					name = requester_name,
					time = time_left,
					unit = time_left == 1 and translate("wire_game_core.units.second") or translate("wire_game_core.units.seconds")
				})
				
				self.TimeLeft = time_left
			end
			
			--not localized because we need to do special stuff
			draw.DrawText(panel_info_text, "DermaDefault", w * 0.5, margin, color_white, TEXT_ALIGN_CENTER)
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

local function should_collide(ply, obstacle)
	
end

local function update_game_bar()
	game_bar.label_title:SetText(game_settings[game_master_index].title)
	game_bar.label_master:SetText(translate("wire_game_core.bar.host", {name = game_master:Nick()}))
end

--post function setup
calc_vars()

--concommand
concommand.Add("wire_game_core_debug", function()
	print("game_settings")
	PrintTable(game_settings, 1)
end, nil, "Debug info for game core.")

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
	
	game_bar.Active = false
	game_bar.Percent = 0
	game_bar.Speed = 3
	
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
	
	function game_bar:SetActive(active)
		active = tobool(active) or false
		
		if self.Active ~= active then
			self.Active = active
			
			if active then self:SetVisible(true)
			else self:SetVisible(self.Percent ~= 0) end
		end
	end
	
	function game_bar:Think()
		local old_percent = self.Percent
		local percent = math.Clamp(old_percent + RealFrameTime() * (self.Active and self.Speed or -self.Speed), 0, 1)
		
		if percent ~= old_percent then
			self.Percent = percent
			
			if percent == 0 then
				self:SetPos(game_bar_x, scr_h)
				self:SetVisible(false)
			else self:SetPos(game_bar_x, scr_h - math.sin(percent * game_bar_animation_curve) ^ 0.75 * game_bar_h) end
		end
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
		label_master:SetText("#wire_game_core.bar.host.unknown")
		
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
		
		button_leave:SetText("#wire_game_core.bar.leave")
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
		
		button_hide:SetText("#wire_game_core.settings.visibility." .. player_visibility)
		button_hide:SetTextColor(color_button_text)
		
		function button_hide:DoClick()
			player_visibility = player_visibility % 3 + 1
			
			adjust_player_visibility()
			
			if player_visibility_button then player_visibility_button:SetText("#wire_game_core.settings.visibility." .. player_visibility) end
			
			self:SetText("#wire_game_core.settings.visibility." .. player_visibility)
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
	context_menu_open = false
	
	if game_master_index then
		game_bar:SetActive(false)
		game_bar:SetParent(GetHUDPanel())
		game_bar:SetMouseInputEnabled(false)
	end
end)

hook.Add("OnContextMenuOpen", "wire_game_core", function()
	context_menu_open = true
	--TODO: figure out what the heck is happenning with game bar's animations
	if game_master_index then
		game_bar:SetActive(true)
		game_bar:SetParent(context_menu)
		game_bar:SetMouseInputEnabled(true)
		
		timer.Remove("wire_game_core_game_bar_close")
	end
end)

hook.Add("OnScreenSizeChanged", "wire_game_core", calc_vars)
hook.Add("PlayerNoClip", "wire_game_core", function(ply, desire) if game_masters[ply:EntIndex()] and desire then return false end end)
hook.Add("PopulateToolMenu", "wire_game_core", function() spawnmenu.AddToolMenuOption("Utilities", "User", "WireGameCore", "E2 Game Core", "", "", generate_settings_form) end)

--not yet, I still want to test
--hook.Add("SpawnMenuOpen", "wire_game_core", function() if game_master_index then return false end end)

hook.Add("ShouldCollide", "wire_game_core", function(ent_1, ent_2)
	
	
	--[[
	if ent_1:IsPlayer() and ent_2:IsPlayer() then
		local ent_1_master = game_masters[ent_1:EntIndex()]
		local ent_2_master = game_masters[ent_2:EntIndex()]
		
		if ent_1_master and ent_1_master == ent_2_master then return game_settings[ent_1_master].ply_collide end
		if ent_1_master ~= ent_2_master then return false end
	end --]]
	
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

net.Receive("wire_game_core_collidables", function()
	--todo: more networked tables like this
	repeat
		local master_index = net.ReadUInt(8)
		
		repeat
			local ent_index = net.ReadUInt(13)
			local collidable = net.ReadBool() or nil --if it's false, just make it nil
			
			if game_collidables[master_index] then game_collidables[master_index][ent_index] = collidable
			elseif collidable then game_collidables[master_index] = {[ent_index] = collidable} end
		until not net.ReadBool()
		
		--discard the bitch
		if table.IsEmpty(game_collidables[master_index]) then game_collidables[master_index] = nil end
	until not net.ReadBool()
end)

net.Receive("wire_game_core_join", function()
	game_bar_desired = true
	game_master_index = net.ReadUInt(8)
	game_master = Entity(game_master_index)
	local rich_text = game_bar.rich_text
	
	--reading when nothing is there scares me, so lets check
	if net.ReadBool() then weapon_class = net.ReadString() end
	
	rich_text:SetText("")
	
	adjust_player_visibility()
	game_bar_message_ez(false, {255, 255, 128}, "You joined " .. game_master:Nick() .. "'s game.")
	
	if context_menu_open then game_bar:SetActive(true)
	else
		game_bar:SetActive(true)
		
		timer.Create("wire_game_core_game_bar_close", 5 + 1 / 3, 1, function()
			--short timers are okay by my standard
			game_bar_desired = false
			
			game_bar:SetActive(false)
		end)
	end
end)

net.Receive("wire_game_core_leave", function()
	game_bar:SetActive(false)
	
	game_bar_desired = false
	
	if weapon_class then
		local weapon = me:GetWeapon(weapon_class)
		
		--uggghhhhh predicted BULLSHit
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

net.Receive("wire_game_core_message", function()
	local message_table = net.ReadTable()
	
	if message_table then
		local new_line = net.ReadBool()
		local notify = net.ReadBool()
		
		game_bar_message(new_line, message_table)
		
		if notify then
			game_bar:SetActive(true)
			
			timer.Create("wire_game_core_game_bar_close", math.Clamp(net.ReadFloat(), 1, 10), 1, function()
				--short timers are okay by my standard
				game_bar_desired = false
				
				game_bar:SetActive(false)
			end)
		end
	else
		
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
	--not sufficient! we need to stop using net.WriteTable!
	local received_settings = net.ReadTable()
	
	if IsValid(browser) and IsValid(browser.GameEntryContainer) then
		local game_entry_container = browser.GameEntryContainer
		
		for master_index, settings in pairs(received_settings) do 
			--if the settings are false instead of a table, they were removed
			local game_entry = game_entry_container:GetEntry(master_index) --game_entry
			
			if settings == false then
				--remove entry
				game_entry_container:RemoveEntry(master_index)
				
				--don't need this anymore looool
				game_entry_container.GameEntryHeaders[master_index] = nil
				game_settings[master_index] = nil
			else
				--this will also create the entry if it did not already exist
				local new_game_entry = game_entry_container:SetSettings(master_index, settings)
				
				--because we have a fancy stencil...
				if not game_entry then game_entry_container.GameEntryHeaders[master_index] = new_game_entry.Header end
				
				--move the entry... should we do this? players might not like this
				if settings.plys or settings.open ~= nil then game_entry_container:CalculateScore(master_index) end
				
				game_settings[master_index] = table.Merge(game_settings[master_index] or {}, settings)
			end
		end
	else
		for master_index, settings in pairs(received_settings) do 
			--if the settings are false instead of a table, they were removed
			if settings == false then game_settings[master_index] = nil
			else game_settings[master_index] = table.Merge(game_settings[master_index] or {}, settings) end
		end
	end
	
	--close requests for closed games
	if held_requests[1] then
		local cur_time = CurTime()
		
		--make all requests for closing games expire
		for index, data in ipairs(held_requests) do if not game_settings[data[1]] then held_requests[index][3] = true end end
	end
	
	if game_master_index and game_settings[game_master_index] then update_game_bar() end
end)

--auto reload, will be removed in the future
if WireGameCore then
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
else WireGameCore = true end