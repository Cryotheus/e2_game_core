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
local me
local me_index
local rad_to_deg = (2 * math.pi) / 360
local response_made = false
local settings_form
local weapon_class

--scoped functions
local generate_block_form
local open_request_gui

----colors
	local color_button_text = Color(224, 224, 224)
	local color_dark = Color(26, 26, 26)
	local color_dark_baseboard = Color(30, 30, 30)
	local color_dark_button = Color(36, 36, 36)
	local color_dark_header = Color(44, 44, 44)
	local color_dark_text = Color(96, 96, 96)
	local color_expression = Color(150, 34, 34)
	local color_expression_excited = Color(158, 47, 47)
	local color_game_highlight = Color(128, 255, 128)
	local color_game_indicator = Color(192, 255, 192)

--render parameters
local block_form
local button_reload
local browser
local browser_h
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
local game_bar_button_hide_h
local game_bar_button_hide_phrases = {"Hide Excluded Players", "Hide All Players", "Reveal Players"}
local game_bar_button_hide_y
local game_bar_button_leave_h
local game_bar_button_leave_w
local game_bar_button_leave_y
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

----chached functions
	local fl_cam_End2D = cam.End2D
	local fl_cam_Start2D = cam.Start2D
	local fl_render_ClearStencil = render.ClearStencil
	local fl_render_SetStencilCompareFunction = render.SetStencilCompareFunction
	local fl_render_SetStencilEnable = render.SetStencilEnable
	local fl_render_SetStencilFailOperation = render.SetStencilFailOperation
	local fl_render_SetStencilPassOperation = render.SetStencilPassOperation
	local fl_render_SetStencilReferenceValue = render.SetStencilReferenceValue
	local fl_render_SetStencilTestMask = render.SetStencilTestMask
	local fl_render_SetStencilWriteMask = render.SetStencilWriteMask
	local fl_render_SetStencilZFailOperation = render.SetStencilZFailOperation
	local fl_surface_DrawRect = surface.DrawRect
	local fl_surface_DrawTexturedRectRotated = surface.DrawTexturedRectRotated
	local fl_surface_SetDrawColor = surface.SetDrawColor
	local fl_surface_SetTexture = surface.SetTexture

--local functions
local function add_block_checkbox(ply)
	local check_box = vgui.Create("DCheckBoxLabel", block_form)
	local master_index = ply:EntIndex()
	
	check_box:SetText(ply:Nick())
	check_box:SetTextColor(color_black)
	
	if game_blocks[master_index] then check_box:SetChecked(false)
	else check_box:SetChecked(true) end
	
	check_box.OnChange = function(self, checked)
		if IsValid(ply) then
			for master_index, panel in pairs(game_blocks_check_boxes) do panel:SetEnabled(false) end
			
			net.Start("wire_game_core_block")
			net.WriteUInt(master_index, 8)
			net.WriteBool(not checked)
			net.SendToServer()
			
			timer.Create("wire_game_core_block_form_timeout", 5, 1, generate_block_form)
		else self:Remove() end
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
		
		print("hide", value, override)
		
		hook.Add("PrePlayerDraw", "wire_game_core", player_visibility_function)
		hook.Add("HUDDrawTargetID", "wire_game_core", function() return true end)
		
		for _, ply in pairs(player.GetAll()) do
			if ply == me then continue end
			
			player_visibility_set_function(ply)
		end
	else
		local player_visibility_set_function = player_visibility_set_functions[1]
		
		print("clear", value, override)
		
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
	elseif self.Hovered then fl_surface_SetDrawColor(color_dark_header)
	else fl_surface_SetDrawColor(color_dark_button) end
	
	fl_surface_DrawRect(0, 0, w, h)
end

local function calc_cogs(start_rate, start_size, start_x, start_y, ideas, debugging)
	local cogs = {}
	local current_angle = 0
	local current_x = start_x
	local current_y = start_y
	local last_size = start_size * cog_size
	
	local first_cog_index = table.insert(cogs, {
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
		
		local current_cog = table.insert(cogs, {
			offset = idea.offset,
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
	local margin_double = margin * 2
	local margin_half = margin * 0.5
	
	scr_h = ScrH()
	scr_w = ScrW()
	
	browser_h = scr_h - browser_margin_double
	browser_w = scr_w - browser_margin_double
	browser_x = browser_margin
	browser_y = browser_margin
	
	game_bar_animation_curve = 0.5
	game_bar_animation_duration = 0.3
	game_bar_h = scr_h * 0.15
	game_bar_w = scr_w * 0.4
	game_bar_x = (scr_w - game_bar_w) * 0.5
	game_bar_y = scr_h - game_bar_h
	
	game_bar_button_leave_h = (game_bar_h - game_bar_header) * 0.25 - margin - margin_half
	game_bar_button_leave_w = game_bar_w * 0.25 - margin_double
	game_bar_button_leave_y = game_bar_header + margin
	
	game_bar_button_hide_h = game_bar_button_leave_h
	game_bar_button_hide_y = game_bar_button_leave_y + game_bar_button_leave_h + margin
	
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
	
	--[[
	debug_panel_cogs = calc_cogs(10, 1, 400, 400, {
		{
			angle = 45,
			offset = 0,
			size = 1
		},
		{
			angle = 45,
			offset = 0,
			size = 0.5
		},
		{
			angle = 90,
			offset = 0,
			size = 0.25
		},
		{
			angle = 0,
			offset = 0,
			size = 0.5
		},
		{
			angle = 0,
			offset = 0,
			size = 1
		},
		{
			angle = 30,
			offset = 0,
			size = 0.5
		},
		{
			angle = 68,
			offset = 0,
			size = 1
		},
		{
			angle = -24,
			offset = 0,
			size = 2
		},
		{
			angle = 106,
			offset = 0,
			size = 0.5
		},
		{
			angle = -45,
			offset = 0,
			size = 1.5
		},
		{
			angle = 45,
			offset = 0,
			size = 0.5
		},
		{
			angle = 80,
			offset = 0,
			size = 1
		},
		{
			angle = 10,
			offset = 0,
			size = 0.5
		}
	}, true) --]]
	
	---[[
	debug_panel_cogs = calc_cogs(10, 1, 200, 200, {
		{
			angle = -45,
			size = 1
		},
		{
			angle = 90,
			size = 1
		},
		{
			angle = 60,
			size = 1
		},
		{
			angle = 40,
			size = 1
		},
		{
			angle = -45,
			size = 1
		},
	}, true) --]]
	
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
end

local function draw_cogs(cogs)
	local real_time = RealTime()
	
	fl_surface_SetDrawColor(color_expression)
	fl_surface_SetTexture(cog_texture)
	
	for index, cog in pairs(cogs) do fl_surface_DrawTexturedRectRotated(cog.x, cog.y, cog.size, cog.size, real_time * cog.rate + cog.offset) end
end

local function forward_response(enum)
	pop_up = nil
	response_made = true
	
	net.Start("wire_game_core_request")
	net.WriteInt(enum, 8)
	net.WriteUInt(held_requests[1][1], 8)
	net.SendToServer()
	
	--remove queued requests if we accepted the request, or go to the next if we have one
	if enum > 0 then held_requests = {}
	else
		table.remove(held_requests, 1)
		
		if not table.IsEmpty(held_requests) then open_request_gui() end
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
	
	player_visibility_button = vgui.Create("DButton", settings_form)
	
	player_visibility_button:SetText(game_bar_button_hide_phrases[player_visibility])
	settings_form:AddItem(player_visibility_button)
	
	player_visibility_button.DoClick = function(self)
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

open_request_gui = function()
	held_requests[1][2] = CurTime() + 30
	pop_up = vgui.Create("DFrame", nil, "GameCoreRequest")
	response_made = false
	
	local pop_up_layout = pop_up.PerformLayout
	local requester_index = held_requests[1][1]
	local requester = Entity(requester_index)
	
	pop_up:SetTitle("Game request from " .. requester:Nick())
	pop_up:SetSize(pop_up_w, pop_up_h)
	
	--we won't need the minimize button
	pop_up.btnMinim:SetVisible(false)
	
	--close/deny button, reuses the close button
	local button_close = pop_up.btnClose
	
	button_close:SetText("Deny")
	button_close:SetTextColor(color_white)
	
	button_close.DoClick = function(self)
		pop_up:Remove()
		forward_response(-1)
	end
	
	button_close.Paint = function(self, w, h)
		if self.Depressed or self:IsSelected() or self:GetToggle() then fl_surface_SetDrawColor(color_expression) 
		elseif self.Hovered then fl_surface_SetDrawColor(color_dark_baseboard)
		else fl_surface_SetDrawColor(color_dark_button) end
		
		fl_surface_DrawRect(0, 2, w, h - 4)
	end
	
	--block button, reuses the maximize button
	local button_block = pop_up.btnMaxim
	
	button_block:SetEnabled(true)
	button_block:SetFont("DermaDefaultBold")
	button_block:SetText("BLOCK")
	button_block:SetTextColor(color_white)
	
	button_block.DoClick = function(self)
		game_blocks[requester_index] = true
		game_blocks_check_boxes[requester_index]:SetChecked(false)
		
		pop_up:Remove()
		forward_response(-3)
	end
	
	button_block.Paint = function(self, w, h)
		if self.Depressed or self:IsSelected() or self:GetToggle() then fl_surface_SetDrawColor(color_expression) 
		elseif self.Hovered then fl_surface_SetDrawColor(color_expression_excited)
		else fl_surface_SetDrawColor(color_expression) end
		
		fl_surface_DrawRect(0, 2, w, h - 4)
	end
	
	--accept button
	local button_accept = vgui.Create("DButton", pop_up)
	
	button_accept:SetPos(margin, pop_up_button_accept_y)
	button_accept:SetSize(pop_up_button_accept_w, pop_up_button_accept_h)
	button_accept:SetText("Accept")
	button_accept:SetTextColor(color_white)
	
	button_accept.DoClick = function(self)
		pop_up:Remove()
		forward_response(1)
	end
	
	button_accept.Paint = button_paint
	
	--deny button
	local button_deny = vgui.Create("DButton", pop_up)
	
	button_deny:SetPos(pop_up_button_deny_x, pop_up_button_accept_y)
	button_deny:SetSize(pop_up_button_accept_w, pop_up_button_accept_h)
	button_deny:SetText("Deny")
	button_deny:SetTextColor(color_white)
	
	button_deny.DoClick = button_close.DoClick
	button_deny.Paint = button_paint
	
	--info box
	local panel_info = vgui.Create("DPanel", pop_up)
	local panel_info_text = requester:Nick() .. " has invited you to join their game.\n\nAccepting will grant them more access with Expression 2,\nbut you can revoke their access at anytime by using the context menu."
	
	panel_info:SetPos(margin, pop_up_panel_info_y)
	panel_info:SetSize(pop_up_panel_info_w, pop_up_panel_info_h)
	
	panel_info.Paint = function(self, w, h)
		local time_left = math.ceil(held_requests[1][2] - CurTime())
		
		draw.DrawText(panel_info_text .. "\n\nThis invite expires in " .. time_left .. (time_left == 1 and " second." or " seconds."), "DermaDefault", w * 0.5, margin, color_white, TEXT_ALIGN_CENTER)
	end
	
	pop_up.Paint = function(self, w, h)
		fl_surface_SetDrawColor(color_dark)
		fl_surface_DrawRect(0, 0, w, h)
		
		draw_cogs(pop_up_cogs)
		
		fl_surface_SetDrawColor(color_dark_header)
		fl_surface_DrawRect(0, 0, w, header)
		
		fl_surface_SetDrawColor(color_dark_baseboard)
		fl_surface_DrawRect(0, pop_up_baseboard_y, w, pop_up_baseboard_h)
	end
	
	--we have to modify the close and maxim buttons here, as they are changed in this function
	pop_up.PerformLayout = function(self)
		pop_up_layout(self)
		
		self.btnClose:SetPos(self:GetWide() - 52, 0)
		self.btnClose:SetWide(48, 24)
		
		self.btnMaxim:SetPos(self:GetWide() - 104, 0)
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
	if game_bar_animating then return end
	
	if state then
		if not game_bar_open then
			--open
			game_bar_animating = true
			game_bar_open = true
			
			local game_bar_animation = game_bar:NewAnimation(game_bar_animation_duration, 0, game_bar_animation_curve, function()
				game_bar_animating = false
				
				game_bar:SetPos(game_bar_x, game_bar_y)
				
				if not game_bar_desired or not game_master_index then show_game_bar(false) end
				if finish then finish() end
			end)
			
			game_bar_animation.Think = function(self, panel, fraction) game_bar:SetPos(game_bar_x, scr_h - fraction * game_bar_h) end
		end
	else
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
			
			game_bar_animation.Think = function(self, panel, fraction) game_bar:SetPos(game_bar_x, game_bar_y + fraction * game_bar_h) end
		end
	end
end

local function update_game_bar()
	game_bar.label_title:SetText(game_settings[game_master_index].title)
	game_bar.label_master:SetText("Hosted by " .. game_master:Nick())
end

--post function setup
calc_vars()

--concommand
concommand.Add("wire_game_core_debug", function()
	--this stuff is also being used for autoreload, but is safe to run anyways
	local context_menu = vgui.GetWorldPanel():Find("ContextMenu")
	local hooks = hook.GetTable()
	
	hooks.ContextMenuCreated.wire_game_core(context_menu)
	hooks.InitPostEntity.wire_game_core()
	print("entities", me, me_index)
	print("held requests")
	PrintTable(held_requests, 1)
	print("game_blocks")
	PrintTable(game_blocks)
	print("game settings")
	PrintTable(game_settings)
end, nil, "Debug for game core, will be removed,")

concommand.Add("wire_game_core_debug_cogs", function()
	local frame = vgui.Create("DFrame")
	
	frame:SetSize(800, 800)
	frame:SetTitle("Cog Debugger")
	
	local cog_panel = vgui.Create("DPanel", frame)
	
	cog_panel:Dock(FILL)
	cog_panel:DockMargin(4, 4, 4, 4)
	
	cog_panel.Paint = function(self, w, h)
		fl_surface_SetDrawColor(color_dark)
		fl_surface_DrawRect(0, 0, w, h)
		
		draw_cogs(pop_up_cogs)
	end
	
	frame:Center()
	frame:MakePopup()
end, nil, "Debug for game core, used to debug the cog algorithm.")

concommand.Add("wire_game_core_debug_browser", function()
	browser = vgui.Create("DFrame")
	
	browser:SetDraggable(false)
	browser:SetPos(browser_x, browser_y)
	browser:SetSize(browser_w, browser_h)
	browser:SetTitle("Game Browser")
	
	browser.Paint = function(self, w, h)
		fl_surface_SetDrawColor(color_dark)
		fl_surface_DrawRect(0, 0, w, h)
		
		draw_cogs(game_bar_cogs)
		
		fl_surface_SetDrawColor(color_dark_header)
		fl_surface_DrawRect(0, 0, w, header)
	end
	
	browser:MakePopup()
end, nil, "Debug for game core, used to develop the game browser.")

--game events
gameevent.Listen("player_connect")

--hooks
hook.Add("ContextMenuCreated", "wire_game_core", function(panel)
	print("================= context menu create", panel)
	
	context_menu = panel
	game_bar = vgui.Create("EditablePanel", GetHUDPanel(), "GameCoreGameBar")
	--
	game_bar:SetMouseInputEnabled(true)
	game_bar:SetPos(game_bar_x, scr_h)
	game_bar:SetSize(game_bar_w, game_bar_h)
	
	game_bar.Paint = function(self, w, h)
		fl_surface_SetDrawColor(color_dark)
		fl_surface_DrawRect(0, 0, w, h)
		
		draw_cogs(game_bar_cogs)
		
		fl_surface_SetDrawColor(color_dark_header)
		fl_surface_DrawRect(0, 0, w, game_bar_header)
	end
	
	local label_title = vgui.Create("DLabel", game_bar)
	
	label_title:Dock(TOP)
	label_title:SetContentAlignment(5)
	label_title:SetFont("CreditsText")
	label_title:SetHeight(game_bar_header * 0.6)
	label_title:SetText("Unknown Game")
	game_bar.label_title = label_title
	
	local label_master = vgui.Create("DLabel", game_bar)
	
	label_master:Dock(TOP)
	label_master:SetColor(color_dark_text)
	label_master:SetContentAlignment(5)
	label_master:SetHeight(game_bar_header * 0.4)
	label_master:SetText("Unknown Host")
	game_bar.label_master = label_master
	
	local button_leave = vgui.Create("DButton", game_bar)
	
	button_leave:SetPos(margin, game_bar_button_leave_y)
	button_leave:SetSize(game_bar_button_leave_w, game_bar_button_leave_h)
	button_leave:SetText("Leave Game")
	button_leave:SetTextColor(color_button_text)
	
	button_leave.DoClick = function(self)
		--idontwannaplayheavyanymore
		net.Start("wire_game_core_leave")
		net.SendToServer()
	end
	
	local button_hide = vgui.Create("DButton", game_bar)
	
	button_hide:SetPos(margin, game_bar_button_hide_y)
	button_hide:SetSize(game_bar_button_leave_w, game_bar_button_leave_h)
	button_hide:SetText(game_bar_button_hide_phrases[player_visibility])
	button_hide:SetTextColor(color_button_text)
	
	button_hide.DoClick = function(self)
		player_visibility = player_visibility % 3 + 1
		
		adjust_player_visibility()
		
		if player_visibility_button then player_visibility_button:SetText(game_bar_button_hide_phrases[player_visibility]) end
		
		self:SetText(game_bar_button_hide_phrases[player_visibility])
	end
	
	button_hide.Paint = button_paint
	button_leave.Paint = button_paint
	
	game_bar.button_hide = button_hide
end)

hook.Add("InitPostEntity", "wire_game_core", function()
	me = LocalPlayer()
	me_index = me:EntIndex()
	
	request_full_sync()
	
	local distance_alpha_max_alpha = 64
	local distance_alpha_max_distance = 512
	local distance_alpha_min_distance = 128
	
	hook.Add("PostDrawTranslucentRenderables", "wire_game_core", function(ply)
		--we should instead drop this into the InitPostEntity hook but that'd stop autoreload for doing its bussiness
		for index, ply in pairs(player.GetAll()) do
			if game_masters[ply:EntIndex()] then
				if IsValid(ply) and ply:Alive() then
					--I know this is expensive, but how else can I get a linear fading alpha
					local distance = ply:GetPos():Distance(me:GetPos())
					
					if distance < distance_alpha_max_distance then
						local distance_alpha = 0
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
end)

hook.Add("OnContextMenuClose", "wire_game_core", function()
	game_bar_desired = false
	
	game_bar:ParentToHUD()
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
	
	if game_master_index then
		--
		show_game_bar(true)
	end
end)

hook.Add("OnScreenSizeChanged", "wire_game_core", calc_vars)
hook.Add("player_connect", "wire_game_core", function() timer.Simple(2, generate_block_form) end)
hook.Add("PlayerNoClip", "wire_game_core", function(ply, desire) if game_masters[ply:EntIndex()] and desire then return false end end)
hook.Add("PopulateToolMenu", "wire_game_core", function() spawnmenu.AddToolMenuOption("Utilities", "User", "WireGameCore", "E2 Game Core", "", "", generate_settings_form) end)

--hook.Add("SpawnMenuOpen", "wire_game_core", function() if game_master_index then return false end end)

hook.Add("ShouldCollide", "wire_game_core", function(ent_1, ent_2)
	if ent_1:IsPlayer() and ent_2:IsPlayer() and game_masters[ent_1:EntIndex()] ~= game_masters[ent_2:EntIndex()] then return false end
	
	return true
end)

hook.Add("Think", "wire_game_core", function()
	local cur_time = CurTime()
	local new_requests = {}
	
	for index, data in ipairs(held_requests) do
		--can't use table.remove or it skips over indices
		local master_index = data[1]
		
		if cur_time < data[2] then table.insert(new_requests, data)
		elseif index == 1 and pop_up then
			pop_up:Remove()
			forward_response(-2)
		end
	end
	
	--can we please have a reliable PlayerDisconnected hook?
	--oh, and don't even think for a second that the game event is more reliable
	--for master_index, panel in pairs(game_blocks_check_boxes) do if not IsValid(Entity(master_index)) then panel:Remove() end end
	
	held_requests = new_requests
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

net.Receive("wire_game_core_join", function()
	game_bar_desired = true
	game_master_index = net.ReadUInt(8)
	weapon_class = net.ReadString()
	
	--let's cache the player so we don't have to keep fetching them
	game_master = Entity(game_master_index)
	
	show_game_bar(true, function()
		timer.Create("wire_game_core_game_bar_close", 5, 1, function()
			--short timers are okay by my standard
			game_bar_desired = false
			
			show_game_bar(false)
		end)
	end)
	
	adjust_player_visibility()
end)

net.Receive("wire_game_core_leave", function()
	show_game_bar(false)
	
	game_bar_desired = false
	
	if weapon_class then
		local weapon = me:GetWeapon(weapon_class)
		
		--it's fine to do SelectWeapon like this, I swear
		timer.Simple(0.1, function() if IsValid(weapon) then input.SelectWeapon(weapon) end end)
		
		game_master = nil
		game_master_index = nil
		weapon_class = nil
	end
	
	print("we left")
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
		--let's make it curtime, because server lag also delays the respone
		local cur_time = CurTime()
		
		for index, data in pairs(held_requests) do
			--don't re-add the entry, just renew the time
			local master_index = data[1]
			
			if requests[master_index] then
				held_requests[index][2] = cur_time
				requests[master_index] = nil
			end
		end
		
		for master_index in pairs(requests) do table.insert(held_requests, {master_index, cur_time}) end
		
		open_request_gui()
	end
end)

net.Receive("wire_game_core_sounds", function()
	local sounds = net.ReadTable()
	
	for index, sound_path in pairs(sounds) do surface.PlaySound(sound_path) end
end)

net.Receive("wire_game_core_sync", function()
	local received_settings = net.ReadTable()
	
	table.Merge(game_settings, received_settings)
	
	if game_master_index and received_settings[game_master_index] then
		--when we receive an update about the game are in, do stuff
		update_game_bar()
	end
end)

--auto reload, will be removed in the future
if LocalPlayer() then RunConsoleCommand("wire_game_core_debug")
else
	--[[surface.CreateFont("GameCoreTitle", {
		extended = true,
		font = "Roboto",
		size = 
	})]]
end