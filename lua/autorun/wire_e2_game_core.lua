--refer to link below for more information
--https://github.com/Cryotheus/minge_defense/blob/main/gamemodes/mingedefense/gamemode/loader.lua
local config = {
	--files at gamemode root, these are not run by this loader
	autorun = {wire_e2_game_core = 4},
	
	wire_game_core = {
		client = 13,	--1 101
		server = 10,	--1 010
		
		includes = {
			colors = 4,		--0 100
			tags = 4,		--0 100
			translate = 4	--0 100
		},
		
		panels = {
			browser_game_entry = 5,		--0 101
			browser_tag = 5,			--0 101
			browser_tag_container = 5	--0 101
		}
	}
}

--maximum amount of folders it may go down in the config tree
local max_depth = 4

--local variables, don't change
local fl_bit_band = bit.band
local fl_bit_rshift = bit.rshift
local highest_priority = 0
local load_order = {}
local load_functions = {
	[1] = function(path) if CLIENT then include(path) end end,
	[2] = function(path) if SERVER then include(path) end end,
	[4] = function(path) if SERVER then AddCSLuaFile(path) end end
}

local load_function_shift = table.Count(load_functions)

----colors
	local associated_colors = include("wire_game_core/includes/colors.lua")
	local color_print_red = associated_colors.color_print_red
	local color_print_white = associated_colors.color_print_white

--local functions
local function construct_order(config_table, depth, path)
	local tabs = " ]" .. string.rep("    ", depth)
	
	for key, value in pairs(config_table) do
		if type(value) == "table" then
			MsgC(color_print_white, tabs .. key .. ":\n")
			
			if depth < max_depth then construct_order(value, depth + 1, path .. key .. "/")
			else MsgC(color_print_red, tabs .. "    !!! MAX DEPTH !!!\n") end
		else
			MsgC(color_print_white, tabs .. key .. " = 0d" .. value .. "\n")
			
			local priority = fl_bit_rshift(value, load_function_shift)
			local script_path = path .. key
			
			if priority > highest_priority then highest_priority = priority end
			if load_order[priority] then load_order[priority][script_path] = fl_bit_band(value, 7)
			else load_order[priority] = {[script_path] = fl_bit_band(value, 7)} end
		end
	end
end

local function load_by_order()
	for priority = 0, highest_priority do
		local script_paths = load_order[priority]
		
		if script_paths then
			if priority == 0 then MsgC(color_print_white, " Loading scripts at level 0...\n")
			else MsgC(color_print_white, "\n Loading scripts at level " .. priority .. "...\n") end
			
			for script_path, bits in pairs(script_paths) do
				local script_path_extension = script_path .. ".lua"
				
				MsgC(color_print_white, " ]    0d" .. bits .. "	" .. script_path_extension .. "\n")
				
				for bit_flag, func in pairs(load_functions) do if fl_bit_band(bits, bit_flag) > 0 then func(script_path_extension) end end
			end
		else MsgC(color_print_red, "Skipping level " .. priority .. " as it contains no scripts.\n") end
	end
end

local function load_scripts()
	MsgC(color_print_white, "\n\\\\\\ ", color_print_red, "[E2] Game Core", color_print_white, " ///\n\nConstructing load order...\n")
	construct_order(config, 1, "")
	MsgC(color_print_red, "\nConstructed load order.\n\nLoading scripts by load order...\n")
	load_by_order()
	MsgC(color_print_red, "\nLoaded scripts.\n\n", color_print_white, "/// ", color_print_red, "All scripts loaded.", color_print_white, " \\\\\\\n\n")
end

--concommands
concommand.Add("wire_game_core_reload", function(ply)
	--is it possible to run a command from client and execute the serverside command when the command is shared?
	if not IsValid(ply) or ply:IsSuperAdmin() or LocalPlayer and ply == LocalPlayer() then load_scripts() end
end, nil, "Reload all [E2] Game Core scripts excluding the extension scripts.")

--post function setup
load_scripts()