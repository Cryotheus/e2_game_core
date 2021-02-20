--tables
local entity_meta = FindMetaTable("Entity")
local game_blocks = {}			--y for players who blocked others;				k: player index,		v: table where (k: master index, v: true)
local game_camera_counts = {}	--y for cameras the master makes;				k: master index,		v: number
local game_cameras = {}			--y for cameras the master makes;				k: master index,		v: table where
local game_collidables = {}		--y stores collidable props for game players;	k: master index,		v: table where (k: master index, v: true)
local game_constructor = {}		--y for getting the game chip and master;		k: chip/master index,	v: master/chip index
local game_damage_dealt = {}	--y stores dealt damage multipliers;			k: player index,		v: multiplier
local game_damage_taken = {}	--y stores dealt damage multipliers;			k: player index,		v: multiplier
local game_describe_delay = {}	--n stores reset times for game descriptions;	k: master index,		v: when they can next set the description
local game_masters = {}			--y used to fetch the player's game master;		k: player index,		v: master index
local game_message_counts = {}	--y stores the amount of messages sent so far;	k: player index,		v: count of message
local game_message_resets = {}	--y stores reset times for message cooldowns;	k: player index,		v: CurTime when it happens
local game_request_delays = {}	--y to delay requests to certain players;		k: master index,		v: table where (k: recipient index, v: cur_time when they can send another request to the player)
local game_respawns = {}		--y used to store the player's respawn delay;	k: player index,		v: time when the player can respawn
local game_settings = {}		--y stores the settings for each players game;	k: master index,		v: table where (k: setting name, v: setting value)
local ply_cameras = {}			--y stores the cameras each player is viewing;	k: player index,		v: camera index
local ply_meta = FindMetaTable("Player")
local ply_settings = {}			--y for restoring the player;					k: player index,		v: table where (k: state name, v: state value)
local tags = include("wire_game_core/includes/tags.lua") --y					k: sequential index		v: table where (1: tag id, 2: color)

----network queue tables
	local queue_game_collidables = {}	--y
	local queue_game_masters = {}		--y for syncing the game_masters table;			don't remember, should probably check
	local queue_game_requests = {}		--y	stores the requests that are getting sent;	k: player index,	v: table where (k: master index, v: true)
	local queue_game_sounds = {}		--y stores sounds to play on the player;		k: player index,	v: table where (k: sequential index, v: sound path)
	local queue_game_sync = {}			--y stores what settings need syncing;			k: master index,	v: true
	local queue_game_sync_full = {}		--y stores what players need a full sync;		k: player index,	v: true

----network queue checks
	local queue_game_collidables_check = false
	local queue_game_masters_check = false
	local queue_game_requests_check = false
	local queue_game_sounds_check = false
	local queue_game_sync_check = false
	local queue_game_sync_full_check = false

----runOn e2function tables
	local run_game_deaths = {}		--holds the runOnGameDeath subscriptions;			k: entity,	v: true
	local run_game_joins = {}		--holds the runOnGameJoin subscriptions;			k: entity,	v: true
	local run_game_leave = {}		--holds the runOnGameLeave subscriptions;			k: entity,	v: true
	local run_game_requests = {}	--holds the runOnGameRequestResponse subscriptions;	k: entity,	v: true
	local run_game_respawns = {}	--holds the runOnGameRespawn subscriptions;			k: entity,	v: true

----convars
	local convar_limit_settings = {FCVAR_ARCHIVE, FCVAR_NOTIFY}
	
	local gmod_maxammo = GetConVar("gmod_maxammo")
	local wire_game_core_description_delay = CreateConVar("wire_game_core_description_delay", "5", convar_limit_settings, "How long to wait before allowing the player to update their game description.", 1, 60)
	local wire_game_core_max_armor = CreateConVar("wire_game_core_max_armor", "32768", convar_limit_settings, "The maximum amount of armor a player may be given.", 100, 32768)--game_max_description_length = wire_game_core_max_description_length:GetInt()
	local wire_game_core_max_camera_lerp = CreateConVar("wire_game_core_max_camera_lerp", "3600", convar_limit_settings, "The longest a camera lerp can be, in seconds.", 0, 36000)
	local wire_game_core_max_cameras = CreateConVar("wire_game_core_max_cameras", "20", convar_limit_settings, "The maximum amount of point cameras a player may spawn.", 100, 0)
	local wire_game_core_max_damage_multiplier = CreateConVar("wire_game_core_max_damage_multiplier", "1000", convar_limit_settings, "The highest the damage multiplier can be.", 2, 1000)
	local wire_game_core_max_description_length = CreateConVar("wire_game_core_max_description_length", "1024", convar_limit_settings, "The maximum length a game's description can be.", 1, 32768)
	local wire_game_core_max_force = CreateConVar("wire_game_core_max_force", "3500", convar_limit_settings, "The maximum amount of force that may be applied to a player.", 100, 3500)
	local wire_game_core_max_gravity = CreateConVar("wire_game_core_max_gravity", "10", convar_limit_settings, "The maximum amount of health a player may be given.", 1, 100)
	local wire_game_core_max_health = CreateConVar("wire_game_core_max_health", "2147483647", convar_limit_settings, "The maximum amount of health a player may be given.", 100, 2147483647)
	local wire_game_core_max_message_components = CreateConVar("wire_game_core_max_message_components", "32", convar_limit_settings, "The maximum amount of messages the game master may send to their player per second.", 1, 32768)
	local wire_game_core_max_message_length = CreateConVar("wire_game_core_max_message_length", "384", convar_limit_settings, "The maximum length a game message to a player can be.", 1, 32768)
	local wire_game_core_max_messages = CreateConVar("wire_game_core_max_messages", "10", convar_limit_settings, "The maximum amount of messages the game master may send to their player per second.", 0, 32768)
	local wire_game_core_max_sounds = CreateConVar("wire_game_core_max_sounds", "4", convar_limit_settings, "How many sounds the e2 function gamePlayerPlaySound can send to a client in a single tick. This is per client. All sounds are sent in a single net message, the sound path is also truncated to 192 characters.", 0, 32768)
	local wire_game_core_max_speed = CreateConVar("wire_game_core_max_speed", "3500", convar_limit_settings, "The maximum speed a player can have for any movement type.", 600, 3500)
	local wire_game_core_min_gravity = CreateConVar("wire_game_core_min_gravity", "10", convar_limit_settings, "The maximum amount of health a player may be given.", -100, 1)
	local wire_game_core_request_delay = CreateConVar("wire_game_core_request_delay", "5", convar_limit_settings, "How long before the player can receive another game request from the same player.", 1, 60)

----convars cached values, make sure to give the convar a call back!
	local game_description_delay = wire_game_core_description_delay:GetFloat()
	local game_max_ammo = gmod_maxammo:GetInt() ~= 0 and gmod_maxammo:GetInt() or nil
	local game_max_armor = wire_game_core_max_armor:GetInt()
	local game_max_camera_lerp = wire_game_core_max_camera_lerp:GetFloat()
	local game_max_cameras = wire_game_core_max_cameras:GetInt()
	local game_max_damage_multiplier = wire_game_core_max_damage_multiplier:GetFloat()
	local game_max_description_length = wire_game_core_max_description_length:GetInt()
	local game_max_force = wire_game_core_max_force:GetFloat()
	local game_max_gravity = wire_game_core_max_gravity:GetFloat()
	local game_max_health = wire_game_core_max_health:GetInt()
	local game_max_message_components = wire_game_core_max_message_components:GetInt()
	local game_max_message_length = wire_game_core_max_message_length:GetInt()
	local game_max_messages = wire_game_core_max_messages:GetInt()
	local game_max_speed = wire_game_core_max_speed:GetFloat()
	local game_min_gravity = wire_game_core_min_gravity:GetFloat()
	local game_request_delay = wire_game_core_request_delay:GetFloat()
	local queue_game_sounds_max = wire_game_core_max_sounds:GetInt()

----cached functions
	local fl_Entity_SetGravity --if they are only declared here, you can find them detoured in the post local function setup
	local fl_Entity_SetHealth
	local fl_Entity_SetMaxHealth
	local fl_Entity_SetMoveType
	local fl_Entity_SetPos
	local fl_GAMEMODE_PlayerDeathThink = GAMEMODE.PlayerDeathThinkX_GameCore or GAMEMODE.PlayerDeathThink
	local fl_math_Clamp = math.Clamp
	local fl_Player_Give = ply_meta.GiveX_GameCore or ply_meta.Give
	local fl_Player_GiveAmmo = ply_meta.GiveAmmoX_GameCore or ply_meta.GiveAmmo
	local fl_Player_GodDisable
	local fl_Player_GodEnable
	local fl_Player_RemoveAllAmmo
	local fl_Player_RemoveAllItems
	local fl_Player_SetAmmo
	local fl_Player_SetArmor
	local fl_Player_SetCrouchedWalkSpeed
	local fl_Player_SetEyeAngles
	local fl_Player_SetFOV
	local fl_Player_SetJumpPower
	local fl_Player_SetLadderClimbSpeed
	local fl_Player_SetMaxArmor
	local fl_Player_SetRunSpeed
	local fl_Player_SetSlowWalkSpeed
	local fl_Player_SetViewEntity = ply_meta.SetViewEntityX_GameCore or ply_meta.SetViewEntity
	local fl_Player_SetWalkSpeed
	local fl_Player_StripAmmo
	local fl_Player_StripWeapon
	local fl_Player_StripWeapons

----compatibility and bonus features from other addons
	local hooks = hook.GetTable()
	
	--function for pushing the player when they press use https://steamcommunity.com/sharedfiles/filedetails/?id=293535327
	local pac_present = pace and true or false
	local push_mod_hook = PushModHook_GameCore or hooks.KeyPress and hooks.KeyPress["ussy ussy ur a pussy"] or nil
	local ulib_teams = ULXUTeamSpawnAuthHook_GameCore

--constants
local game_constants = { --in e2, these are all prefixed with _GAME, meaning REQUEST_ACCEPT becomes _GAMEREQUEST_ACCEPT
	LEAVE_CHOICE =		1, --the player chose to leave by choice
	LEAVE_DISCONNECT =	2, --the player left the game because they disconnect from the server
	LEAVE_REMOVED =		3, --the player was removed from the game by code
	LEAVE_UNKNOWN =		4, --dunno
	
	RESPAWNMODE_INSTANT =	1, --instantly respawn the player
	RESPAWNMODE_DELAYED =	2, --delay their respawn for a bit
	RESPAWNMODE_NEVER =		3, --don't, lol
	--RESPAWNMODE_SPECTATOR =	4, --imediately put them into spectator
	
	RESPONSE_ACCEPT =		 1, --the player accepted the request, and has become part of your game
	RESPONSE_ACCEPT_FORCED = 2, --the player has become part of your game without consent
	RESPONSE_BLOCKED =		-4, --the player blocked you from sending more requests
	RESPONSE_DENIED =		-3, --the player denied the request
	RESPONSE_NONE		 =	-2, --the player didn't respond within the alotted time
	RESPONSE_SUPERSEDED =	-1, --the player joined someone elses game so your request was denied
	
	REQUEST_BLOCKED =			-1, --the player has you blocked, and the request was not sent
	REQUEST_ESTABLISHED =		-2, --the player is already part of your game
	REQUEST_ESTABLISHED_OTHER =	-3, --the player is already part of someone else's game
	REQUEST_GAMELESS =			-4, --the request was made when there was no game started by the chip
	REQUEST_INVALID_TARGET =	-5, --the request was not sent to a valid player
	REQUEST_LIMITED =			-6, --the request was not sent as you already sent one to this player
	REQUEST_SENT =				 1, --the request was queued to be sent
	REQUEST_UNKNOWN =			 0, --we don't know what happened, but the request was not sent
}

local game_default_settings = {
	defaults = {
		armor = 0,
		crouch_speed = 0.3,
		damage_dealt = 1,
		damage_taken = 1,
		flashlight = false,
		gravity = 1,
		health = 100,
		jump_power = 200,
		ladder_speed = 200,
		max_armor = 100,
		max_health = 100,
		push = push_mod_hook and true or false,
		respawn_delay = 5,
		respawn_mode = game_constants.RESPAWNMODE_DELAYED,
		run_speed = 400,
		stroll_speed = 100,
		walk_speed = 200,
	},
	
	block_fall_damage = false,
	block_suicide = false,
	open = false,
	ply_collide = true,
	plys = {},
	requests = {},
	tags = {},
	title = "Unnamed Game"
}

local game_message_type_ids = {
	s = true,
	v = true,
	xv4 = true
}

--game_respawns
local game_respawn_functions = {
	function(ply) ply:Spawn() end, --RESPAWN_INSTANT
	function(ply) --RESPAWN_DELAYED
		local ply_index = ply:EntIndex()
		local respawn_time = game_respawns[ply_index] or 0
		--finish up the game_respawns table cleanup
		if CurTime() > respawn_time then
			ply:Spawn()
			
			game_respawns[ply_index] = nil
		end
	end,
	function(ply) end, --RESPAWN_NEVER
	function(ply) end --RESPAWN_SPECTATOR
}

local game_synced_settings = { --contains the settings that are sent to clients; k: setting name, v: true
	description = true,
	open = true,
	ply_collide = true,
	plys = true,
	tags = true,
	title = true
}

local map_max_bounds = 32768 + 512 --512 as a buffer
local map_min_bounds = -map_max_bounds
local tag_count = #tags
local weapons_passing = false

----globals
	--access to original, non detoured globals functions
	--other people x them, name space shenans should help if someone wants to make compatibility
	--this is done automatically by the detour macro functions
	GAMEMODE.PlayerDeathThinkX_GameCore = fl_GAMEMODE_PlayerDeathThink
	ply_meta.Give = fl_Player_Give
	ply_meta.GiveAmmo = fl_Player_GiveAmmo
	ply_meta.SetViewEntityX_GameCore = fl_Player_SetViewEntity

--local pre functions
local function ian(num) return num == num end
local function nan(num) return num ~= num end

--local functions
local function active_game(ply) if game_masters[ply:EntIndex()] then return true end end
local function active_game_inv(ply) if game_masters[ply:EntIndex()] then return false end end

local function add_collidable_sync_request(master_index, ent_index, collidable)
	if queue_game_collidables[master_index] then queue_game_collidables[master_index][ent_index] = collidable or false
	else queue_game_collidables[master_index] = {[ent_index] = collidable or false} end
	
	queue_game_collidables_check = true
end

local function add_full_sync_request(ply_index)
	queue_game_sync_full[ply_index] = true
	queue_game_sync_full_check = true
end

local function add_masters_sync_request(ply_index)
	queue_game_masters[ply_index] = true
	queue_game_masters_check = true
end

local function add_sync_request(master_index, key)
	local current_sync = queue_game_sync[master_index]
	
	--if we set this to true, sync everything instead of cherry picking
	if current_sync == true then return end
	
	if key then
		if current_sync then queue_game_sync[master_index][key] = true
		else queue_game_sync[master_index] = {[key] = true} end
	else queue_game_sync[master_index] = true end
	
	queue_game_sync_check = true
end

local function block(blocker_index, blocked_index, state)
	--blocks a master from sending requests to a player, entirely serversided
	if not state then state = nil end
	
	if game_blocks[blocker_index] then game_blocks[blocker_index][blocked_index] = state
	else game_blocks[blocker_index] = {[blocked_index] = state} end
end

local function camera_create(master_index, camera_index, position, angles, force_orientation)
	--creates a camera entity or resturns the existing one
	local camera
	local existed = false
	
	--fetch the existing camera
	if game_cameras[master_index] and game_cameras[master_index][camera_index] then
		camera = game_cameras[master_index][camera_index]
		existed = true
	else
		camera = ents.Create("gmod_wire_game_core_camera")
		
		--this starts the think hook
		camera:Spawn()
	end
	
	--create the table of cameras if we haven't already
	if not game_cameras[master_index] then game_cameras[master_index] = {} end
	
	game_cameras[master_index][camera_index] = camera
	
	--check if we have a camera
	if IsValid(camera) then
		local camera_count = game_camera_counts[master_index]
		
		if camera_count then game_camera_counts[master_index] = camera_count + 1
		else game_camera_counts[master_index] = 1 end
		
		--remove the camera from tables when it is removed, and also reset the player's views
		camera:CallOnRemove("wire_game_core", function()
			for ply_index in pairs(camera.Viewers) do if ply_cameras[ply_index] == camera_index then camera_disable(Entity(ply_index), ply_index, master_index) end end
			
			if table.Count(game_cameras[master_index]) == 1 then game_cameras[master_index] = nil
			else game_cameras[master_index][camera_index] = nil end
			
			if game_camera_counts[master_index] == 1 then game_camera_counts[master_index] = nil
			else game_camera_counts[master_index] = game_camera_counts[master_index] - 1 end
		end)
		
		--orientate the camera if it is a new entity
		if not existed or force_orientation then
			camera:SetAngles(angles)
			camera:SetOwner(Entity(master_index)) --we only do this as an easy way to sync the owner with the client
			camera:SetPos(position)
		end
	end
end

local function camera_disable(ply, ply_index, master_index)
	--return the player's view and remove them from the camera tables
	local camera = game_cameras[master_index][ply_cameras[ply_index]]
	
	--set their view
	fl_Player_SetFOV(ply, 0)
	fl_Player_SetViewEntity(ply)
	
	--update tables
	camera.Viewers[ply_index] = nil
	ply_cameras[ply_index] = nil
end

local function camera_enable(ply, ply_index, master_index, camera_index)
	--set the player's view to the camera by the player, their index, the master index, and camera index
	local camera = game_cameras[master_index][camera_index]
	
	--remove the player from the last camera
	if ply_cameras[ply_index] then camera_disable(ply, ply_index, master_index) end
	
	--set their view
	fl_Player_SetFOV(ply, camera.FOV)
	fl_Player_SetViewEntity(ply, camera)
	
	--update tables
	camera.Viewers[ply_index] = true
	ply_cameras[ply_index] = camera_index
end

local function camera_remove(master_index, camera_index)
	--remove a camera by its master and own index
	game_cameras[master_index][camera_index]:Remove()
end

local function camera_remove_all(master_index)
	--remove all cameras by master index
	for camera_index, camera in pairs(game_cameras[master_index] or {}) do
		--we have the camera, so we can just provide it
		camera:Remove()
	end
end

local function clamp_to_map_bounds(x, y, z)
	--clamp the vector to within the maps maximum bounds if all componenets are a number, otherwise return false
	return ian(x) and ian(y) and ian(z) and Vector(fl_math_Clamp(x, map_min_bounds, map_max_bounds), fl_math_Clamp(y, map_min_bounds, map_max_bounds), fl_math_Clamp(z, map_min_bounds, map_max_bounds)) or false
end

local function clamped_magnitude(x, y, z, magnitude)
	--keep players from having excessive acceleration
	if ian(x) and ian(y) and ian(z) then
		local created_vector = Vector(x, y, z)
		
		if created_vector:LengthSqr() > magnitude ^ 2 then created_vector = created_vector:Normalize() * magnitude end
		
		return created_vector
	end
	
	return false
end

local function construct_game_settings(master_index)
	--sets up the master's game settings
	local master = Entity(master_index)
	local master_name = master:Nick()
	
	game_settings[master_index] = table.Copy(game_default_settings)
	game_settings[master_index].title = master_name .. (master_name[string.len(master_name)] == "s" and "' Game" or "'s Game")
end

local function create_function_detour(function_table, function_name, field, force_value)
	local existing_function = function_table[function_name .. "X_GameCore"] or function_table[function_name]
	
	--give access to the function that doesn't have a detour
	--also used to keep autoreload from stacking them
	function_table[function_name .. "X_GameCore"] = existing_function
	
	--detour the function to our specifications
	if field then
		--we have a field that we need to update
		if force_value then
			--set the field to the force_value when force_value is specified
			function_table[function_name] = function(self, ...)
				local ply_index = self:EntIndex()
				
				if game_masters[ply_index] then
					ply_settings[ply_index][field] = force_value
					
					--[[ debug for this weird "MOVETYPE_FOLLOW" error console spam
					if function_name == "SetMoveType" then
						print("We blocked the move type change to ", interest)
						print("Source (force_value included):")
						debug.Trace()
					end --]]
				else existing_function(self, ...) end
			end
		else
			--take the value from the function and set the field to it
			function_table[function_name] = function(self, interest, ...)
				local ply_index = self:EntIndex()
				
				if game_masters[ply_index] then
					ply_settings[ply_index][field] = interest
					
					--[[ debug for this weird "MOVETYPE_FOLLOW" error console spam
					if function_name == "SetMoveType" then
						print("We blocked the move type change to ", interest)
						print("Source:")
						debug.Trace()
					end --]]
				else existing_function(self, interest, ...) end
			end
		end
	else
		--we don't have a value to provide to ply_settings, just block it if they are in game
		function_table[function_name] = function(self, ...) if not game_masters[self:EntIndex()] then existing_function(self, ...) end end
	end
	
	return existing_function
end

local function create_function_header(function_table, function_name, header)
	local existing_function = function_table[function_name .. "X_GameCore"] or function_table[function_name]
	
	--give access to the function that doesn't have a detour
	--also used to keep autoreload from stacking them
	function_table[function_name .. "X_GameCore"] = existing_function
	
	function_table[function_name] = function(self, ...)
		local ply_index = self:EntIndex()
		
		if game_masters[ply_index] then header(self, ply_index, ...)
		else existing_function(self, ...) end
	end
	
	return existing_function
end

local function game_acclimate(ply, ply_index, defaults)
	--situate the player to the games defaults, used when the player spawns and when they join
	fl_Player_RemoveAllAmmo(ply)
	fl_Player_StripWeapons(ply)
	
	fl_Entity_SetGravity(ply, defaults.gravity)
	fl_Entity_SetHealth(ply, defaults.health)
	fl_Entity_SetMaxHealth(ply, defaults.max_health)
	fl_Player_SetArmor(ply, defaults.armor)
	fl_Player_SetCrouchedWalkSpeed(ply, defaults.crouch_speed)
	fl_Player_SetJumpPower(ply, defaults.jump_power)
	fl_Player_SetLadderClimbSpeed(ply, defaults.ladder_speed)
	fl_Player_SetMaxArmor(ply, defaults.max_armor)
	fl_Player_SetRunSpeed(ply, defaults.run_speed)
	fl_Player_SetSlowWalkSpeed(ply, defaults.stroll_speed)
	fl_Player_SetWalkSpeed(ply, defaults.walk_speed)
	fl_Player_SetViewEntity(ply)
	
	--setting for this later, k?
	fl_Player_GodDisable(ply)
	
	game_damage_dealt[ply_index] = defaults.damage_dealt
	game_damage_taken[ply_index] = defaults.damage_taken
	
	--only change it if it's different, so we don't get the click noise
	if ply:FlashlightIsOn() ~= defaults.flashlight then ply:Flashlight(defaults.flashlight) end
end

local function game_add(ply, master_index)
	--add a player to a game
	local ply_index = ply:EntIndex()
	local ply_weapon = ply:GetActiveWeapon()
	local ply_weapon_class = IsValid(ply_weapon) and ply_weapon:GetClass() or nil
	local settings = game_settings[master_index]
	local settings_defaults = settings.defaults
	
	--do it as early as possible
	ply:CollisionRulesChanged()
	--ply:SetCustomCollisionCheck(true)
	
	game_masters[ply_index] = master_index
	settings.plys[ply_index] = true
	
	ply_settings[ply_index] = {
		ammo = ply:GetAmmo(),
		angle = ply:EyeAngles(),
		armor = ply:Armor(),
		arsenal = {},
		avoid_players = ply:GetAvoidPlayers(),
		crouch_speed = ply:GetCrouchedWalkSpeed(),
		--crouched = ply:Crouching(), --I don't know how to make them crouched
		deaths = ply:Deaths(),
		flashlight = ply:FlashlightIsOn(),
		fov = ply:GetFOV(),
		frags = ply:Frags(),
		god = ply:HasGodMode(),
		gravity = ply:GetGravity(),
		health = ply:Health(),
		jump_power = ply:GetJumpPower(),
		ladder_speed = ply:GetLadderClimbSpeed(),
		max_armor = ply:GetMaxArmor(),
		max_health = ply:GetMaxHealth(),
		move_type = ply:GetMoveType(),
		position = ply:GetPos(),
		run_speed = ply:GetRunSpeed(),
		stroll_speed = ply:GetSlowWalkSpeed(),
		velocity = ply:GetVelocity(),
		walk_speed = ply:GetWalkSpeed()
	}
	
	for index, weapon in pairs(ply:GetWeapons()) do
		local weapon_class = weapon:GetClass()
		
		ply_settings[ply_index].arsenal[weapon_class] = {weapon:Clip1(), weapon:Clip2()}
	end
	
	ply:SetAvoidPlayers(false)
	ply:SetDeaths(0)
	ply:SetFrags(0)
	
	fl_Entity_SetMoveType(ply, MOVETYPE_WALK)
	
	--if there is a pac worn, clear it
	if pac_present then ply:ConCommand("pac_clear_parts") end
	if ply:InVehicle() then ply:ExitVehicle() end
	
	--sets the player to default game settings
	game_acclimate(ply, ply_index, settings_defaults)
	
	--sync!
	add_masters_sync_request(ply_index)
	add_sync_request(master_index, "plys")
	net.Start("wire_game_core_join")
	net.WriteUInt(master_index, 8)
	
	--broken, supposed to make them switch back to their original weapon
	--[[if ply_weapon_class then
		net.WriteBool(true)
		net.WriteString(ply_weapon_class)
	else net.WriteBool(false) end]]
	
	net.Send(ply)
	
	--autobox
	if ply.AAT_GetBadgeProgress then
		local count = table.Count(game_settings[master_index].plys)
		local master = Entity(master_index)
		
		if master:AAT_GetBadgeProgress("game_core") < count then master:AAT_SetBadgeProgress("game_core", count) end
	end
end

local function game_evaluator_constructor_only(self)
	--used to evaluate if the chip is the one who created the game, also returns useful values
	local chip_index = self.entity:EntIndex()
	local master_index = self.player:EntIndex()
	
	if game_constructor[master_index] == chip_index then return true, chip_index, master_index end
	
	return false, chip_index, master_index
end

local function game_evaluator_player_only(self, ply)
	--used to determine if the player is participating in the chip's game, and returns useful values
	local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
	
	if is_constructor and IsValid(ply) and ply:IsPlayer() then
		local ply_index = ply:EntIndex()
		
		if game_masters[ply_index] == master_index then return true, ply_index, chip_index, master_index
		else return false, ply_index, chip_index, master_index end
	end
	
	return false, nil, chip_index, master_index
end

local function game_function_execute(entity, context_fields)
	--macro execute the chip with the given context values
	--a 0 timer keeps the chip from executing with the same context provided by other runOn functions, like runOnChat
	timer.Simple(0, function()
		--did the entity just kill a player during a runOnLast execution? if so it may not be valid, so we check again
		if IsValid(entity) then
			--set the values in context
			for field, value in pairs(context_fields) do entity.context.data[field] = value end
			
			entity:Execute()
			
			--and remove them
			for field, value in pairs(context_fields) do entity.context.data[field] = nil end
		end
	end)
end

local function game_function_players(master_index, func)
	--macro to run a function on every player in the specified master's game
	for ply_index in pairs(game_settings[master_index].plys) do func(Entity(ply_index), ply_index) end
end

local function game_remove(ply, enum)
	--remove the player from the game, and reset them back to their original state
	--code for restoring players after they leave a game
	local ply_index = ply:EntIndex()
	local master_index = game_masters[ply_index]
	local settings = ply_settings[ply_index]
	
	local camera_index = ply_cameras[ply_index]
	local entity = Entity(game_constructor[master_index])
	
	--we gotta do it early
	ply:CollisionRulesChanged()
	--ply:SetCustomCollisionCheck(false)
	
	--if there is no enum, don't execute the chip
	--also, we call this so early so the player can do something before the player leaves
	if enum and run_game_leave[entity] then
		game_function_execute(entity, {
			game_leave_run = enum,
			game_leave_run_ply = ply
		})
	end
	
	add_masters_sync_request(ply_index)
	add_sync_request(master_index, "plys")
	net.Start("wire_game_core_leave")
	net.Send(ply)
	
	game_damage_dealt[ply_index] = nil
	game_damage_taken[ply_index] = nil
	game_settings[master_index].plys[ply_index] = nil
	
	--has to be done later?
	game_masters[ply_index] = nil
	
	--reset the player
	ply:RemoveAllItems()
	ply:SetSuppressPickupNotices(true)
	
	--give them back what they had
	for weapon_class, clips in pairs(settings.arsenal) do
		local weapon = ply:Give(weapon_class, true)
		
		weapon:SetClip1(clips[1])
		weapon:SetClip2(clips[2])
	end
	
	for ammo_type, ammo_count in pairs(settings.ammo) do fl_Player_GiveAmmo(ply, ammo_count, ammo_type, true) end
	
	--reset the player's view
	if ply_settings[ply_index] then
		local camera = game_cameras[camera_index]
		
		if ply_cameras[ply_index] then camera_disable(ply, ply_index, master_index) end
	end
	
	ply:ExitVehicle()
	ply:SetAvoidPlayers(settings.avoid_players)
	ply:SetDeaths(settings.deaths)
	ply:SetEyeAngles(settings.angle)
	ply:SetFrags(settings.frags)
	ply:SetSuppressPickupNotices(false)
	ply:SetVelocity(settings.velocity)
	
	fl_Player_SetFOV(ply, settings.fov)
	fl_Entity_SetGravity(ply, settings.gravity)
	fl_Entity_SetHealth(ply, settings.health)
	fl_Player_SetMaxArmor(ply, settings.max_armor)
	fl_Entity_SetMaxHealth(ply, settings.max_health)
	fl_Entity_SetMoveType(ply, settings.move_type)
	fl_Entity_SetPos(ply, settings.position)
	fl_Player_SetArmor(ply, settings.armor)
	fl_Player_SetCrouchedWalkSpeed(ply, settings.crouch_speed)
	fl_Player_SetJumpPower(ply, settings.jump_power)
	fl_Player_SetLadderClimbSpeed(ply, settings.ladder_speed)
	fl_Player_SetRunSpeed(ply, settings.run_speed)
	fl_Player_SetSlowWalkSpeed(ply, settings.stroll_speed)
	fl_Player_SetWalkSpeed(ply, settings.walk_speed)
	
	--if pac_present then ply:ConCommand("pac_wear_parts") end --ahhhhhhhhhhhhhhhhhhhhhhhhh
	if ply:FlashlightIsOn() ~= settings.flashlight then ply:Flashlight(settings.flashlight) end
	if settings.god then fl_Player_GodEnable(ply) else fl_Player_GodDisable(ply) end
	if IsValid(settings.view_entity) then fl_Player_SetViewEntity(ply, settings.view_entity) end
	
	--remove the settings
	ply_settings[ply_index] = nil
end

local function game_remove_all(master_index, forced)
	--remove every player from a master's game, forced is if the LEAVE_REMOVED enum should be provided to game_remove
	local chip_index = game_constructor[master_index]
	local enum
	
	if not forced then enum = game_constants.LEAVE_REMOVED end
	
	game_function_players(master_index, function(ply) if IsValid(ply) then game_remove(ply, enum) end end)
end

local function game_set_closed(master_index, forced)
	--close a game, and remove all players, forced is if the LEAVE_REMOVED enum should be provided to game_remove
	add_sync_request(master_index)
	camera_remove_all(master_index)
	game_remove_all(master_index, forced)
	
	if game_collidables[master_index] then
		for entity_index in pairs(game_collidables[master_index]) do
			local entity = Entity(entity_index)
			
			if IsValid(entity) then
				entity:CollisionRulesChanged()
				entity:RemoveCallOnRemove("wire_game_core_collidables")
			end
		end
		
		game_collidables[master_index] = nil
	end
	
	--game_collidables[master_index] = nil
	game_constructor[game_constructor[master_index]] = nil
	game_constructor[master_index] = nil
	game_settings[master_index] = nil
end

local function game_write_message(message_table, new_line, notification_duration)
	net.Start("wire_game_core_message")
	
	if message_table then 
		local notify = notification_duration > 0 and true or false
		
		net.WriteBool(true)
		net.WriteTable(message_table)
		net.WriteBool(new_line)
		
		if notify then
			net.WriteBool(true)
			net.WriteFloat(notification_duration)
		else net.WriteBool(false) end
	else net.WriteBool(false) end
end

local function get_context(master_index) return game_constructor[master_index] and Entity(game_constructor[master_index]).context or nil end
local function get_owner(context, entity) return E2Lib.getOwner(context, entity) end

local function give_weapon(ply, master, weapon_class, supress_ammo)
	--give a player a weapon with the master's restrictions
	if not ply:Alive() then return NULL end
	
	local swep = list.Get("Weapon")[weapon_class]
	
	if not swep then return end
	if (swep.AdminOnly or not swep.Spawnable) and not master:IsAdmin() then return NULL end
	
	local swep_class = swep.ClassName
	
	if not ply:HasWeapon(swep_class) then
		weapons_passing = true
		
		return fl_Player_Give(ply, swep_class, supress_ammo)
	end
	
	return NULL
end

local function normalized_angle(pitch, yaw, roll)
	--returns a normalized angle if all components are numbers, otherwise it returns false
	return ian(pitch) and ian(yaw) and ian(roll) and Angle(pitch, yaw, roll):Normalize() or false
end

local function owned_by_master(context, entity)
	--game_masters[ply:EntIndex()]
	--game_constructor[master_index]
	--Entity(game_constructor[master_index]).context
	local owner = get_owner(context, entity)
	
	return IsValid(owner) and owner:EntIndex() == game_constructor[context.entity:EntIndex()]
end

local function player_can_interact(ply, entity)
	local master_index = game_masters[ply:EntIndex()]
	
	if master_index then return owned_by_master(Entity(game_constructor[master_index]).context, entity) end
end

local function parse_message(type_ids, ...)
	local length_remaining = game_max_message_length
	local message_table = {}
	
	for index, value in ipairs({...}) do
		local type_id = type_ids[index]
		
		if game_message_type_ids[type_id] then
			if type_id == "s" then
				value = string.Left(value, length_remaining)
				length_remaining = length_remaining - #value
			end
			
			table.insert(message_table, value)
			
			if length_remaining <= 0 then break end
		end
		
		if index == game_max_message_components then break end
	end
	
	return message_table
end

local function should_collide(ply, obstacle, ply_index, obstacle_index)
	local master_index = game_masters[ply_index]
	
	--players in same game have their collisions determined by game settings
	--other players are not collided with
	if obstacle:IsPlayer() then
		if game_masters[obstacle_index] == master_index then return game_settings[master_index].ply_collide end
		
		return false
	end
	
	if game_collidables[master_index] and game_collidables[master_index][obstacle_index] or obstacle:IsWorld() then return true end
	
	--do we HAVE to return a value? was mitch lying?
	return false
end

local function shouldnt_damage(ply, other, ply_index, other_index)
	--ply is the game's player, it can be the attacker or victim
	if not IsValid(other) then return true end
	if other == ply then return false end
	
	local master_index = game_masters[ply_index]
	
	if other:IsPlayer() then
		--possible team and friendly fire check
		if game_masters[other:EntIndex()] ~= master_index then return true end
		
		return false
	end
	
	if game_collidables[master_index] and game_collidables[master_index][other_index] then return false end
	if owned_by_master(get_context(master_index), other) then return false end
	if other:IsWorld() then return true end --special case here, like a gameEnableWorldDamage e2 function
	
	return true
end

--post function setup
E2Lib.RegisterExtension("game", false,
	"Allows players to have more control over other players, as long as the other player consents. Players will be restored to their original state (including position), upon leaving a game.",
	"Restart the server after disabling!\nThis extension is still in development. Although many measures have been taking to ensure addon intercompatibility, some addons may still break this extension. If any script errors are experienced or a conflict/exploit arises please report it.")

for enum, value in pairs(game_constants) do E2Lib.registerConstant("_GAME" .. enum, value) end
for value, tag_info in ipairs(tags) do E2Lib.registerConstant("_GAMETAG_" .. string.upper(tag_info[1]), value) end

--quick detours
fl_Entity_SetGravity = create_function_detour(entity_meta, "SetGravity", "gravity")
fl_Entity_SetHealth = create_function_detour(entity_meta, "SetHealth", "health")
fl_Entity_SetMaxHealth = create_function_detour(entity_meta, "SetMaxHealth", "max_health")
fl_Entity_SetMoveType = create_function_detour(entity_meta, "SetMoveType", "move_type")
fl_Entity_SetPos = create_function_detour(entity_meta, "SetPos", "position")
fl_Player_GodDisable = create_function_detour(ply_meta, "GodDisable", "god", false)
fl_Player_GodEnable = create_function_detour(ply_meta, "GodEnable", "god", true)

fl_Player_SetArmor = create_function_detour(ply_meta, "SetArmor", "armor")
fl_Player_SetCrouchedWalkSpeed = create_function_detour(ply_meta, "SetCrouchedWalkSpeed", "crouch_speed")
fl_Player_SetEyeAngles = create_function_detour(ply_meta, "SetEyeAngles", "angle")
fl_Player_SetFOV = create_function_detour(ply_meta, "SetFOV", "fov")
fl_Player_SetJumpPower = create_function_detour(ply_meta, "SetJumpPower", "jump_power")
fl_Player_SetLadderClimbSpeed = create_function_detour(ply_meta, "SetLadderClimbSpeed", "ladder_speed")
fl_Player_SetMaxArmor = create_function_detour(ply_meta, "SetMaxArmor", "max_armor")
fl_Player_SetRunSpeed = create_function_detour(ply_meta, "SetRunSpeed", "run_speed")
fl_Player_SetSlowWalkSpeed = create_function_detour(ply_meta, "SetSlowWalkSpeed", "stroll_speed")
fl_Player_SetWalkSpeed = create_function_detour(ply_meta, "SetWalkSpeed", "walk_speed")

fl_Player_RemoveAllAmmo = create_function_detour(ply_meta, "RemoveAllAmmo", "ammo", {})
fl_Player_StripAmmo = create_function_detour(ply_meta, "StripAmmo", "ammo", {})
fl_Player_StripWeapons = create_function_detour(ply_meta, "StripWeapons", "arsenal", {})

--detour headers
fl_Player_RemoveAllItems = create_function_header(ply_meta, "RemoveAllItems", function(ply, ply_index)
	ply_settings[ply_index].ammo = {}
	ply_settings[ply_index].arsenal = {}
end)

fl_Player_SetAmmo = create_function_header(ply_meta, "SetAmmo", function(ply, ply_index, count, ammo_type) ply_settings[ply_index].ammo[isstring(ammo_type) and game.GetAmmoID(ammo_type) or ammo_type] = count end)
fl_Player_StripWeapon = create_function_header(ply_meta, "StripWeapon", function(ply, ply_index, weapon_class) ply_settings[ply_index].arsenal[weapon_class] = nil end)

--we can't just use a hook, because it will still allow the original method provided by the sandbox gamemode
function GAMEMODE:PlayerDeathThink(ply, ...)
	local master_index = game_masters[ply:EntIndex()]
	
	if master_index then game_respawn_functions[game_settings[master_index].defaults.respawn_mode](ply, master_index)
	else fl_GAMEMODE_PlayerDeathThink(GAMEMODE, ply, ...) end
end

function ply_meta:Give(class, no_ammo, ...)
	--we need to make this give ammo in the clip if no_ammo is false/nil
	local ply_index = self:EntIndex()
	
	if not weapons_passing and game_masters[ply_index] then
		if self:HasWeapon(class) then return NULL end
		
		ply_settings[ply_index].arsenal[class] = {0, 0}
	else return fl_Player_Give(self, class, no_ammo, ...) end
	
	return NULL
end

function ply_meta:GiveAmmo(amount, ammo_type, hide_popup, ...)
	local ply_index = self:EntIndex()
	
	if game_masters[ply_index] then
		local converted_type = isstring(ammo_type) and game.GetAmmoID(ammo_type) or ammo_type
		local existing_ammo = ply_settings[ply_index].ammo[converted_type]
		
		ply_settings[ply_index].ammo[converted_type] = game_max_ammo and math.min(amount + existing_ammo, game_max_ammo) or amount + existing_ammo
	else return fl_Player_GiveAmmo(self, amount, ammo_type, hide_popup, ...) end
	
	return 0
end

--probably need to make this work with other things that set it
--I'm thinking of giving it its own setting in ply_settings
function ply_meta:SetViewEntity(view_entity, ...)
	local ply_index = self:EntIndex()
	
	if game_masters[ply_index] then
		--cameras created by wire extras camera core
		if view_entity.IsE2Camera then view_entity.user = nil end
		
		ply_settings[ply_index].view_entity = view_entity
		
		return false
	else fl_Player_SetViewEntity(self, view_entity, ...) end
end

--e2functions
do --camera e2functions
	__e2setcost(8)
	e2function number gameCameraAng(camera_index, angle angle)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor and game_cameras[master_index] then
			local camera = game_cameras[master_index][camera_index]
			
			if camera then
				local angle = normalized_angle(angle[1], angle[2], angle[3])
				
				if angle then
					camera:SetAngles(angle)
					
					return 1
				end
			end
		end
		
		return 0
	end
	
	__e2setcost(18)
	e2function entity gameCameraCreate(camera_index)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		--only allow the game constructor to make cameras
		if is_constructor then
			local camera_count = game_camera_counts[master_index]
			
			--enforce a limit
			if not camera_count or camera_count < game_max_cameras then
				local chip = self.entity
				
				--this will also check if there is an existing entity
				return camera_create(master_index, camera_index, chip:GetPos(), chip:GetAngles(), true)
			end
		end
		
		return NULL
	end
	
	__e2setcost(22)
	e2function entity gameCameraCreate(camera_index, vector position)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		--only allow the game constructor to make cameras
		if is_constructor then
			local camera_count = game_camera_counts[master_index]
			
			--enforce a limit
			if not camera_count or camera_count < game_max_cameras then
				local position = clamp_to_map_bounds(position[1], position[2], position[3])
				
				if position then
					--this will also check if there is an existing entity
					return camera_create(master_index, camera_index, position, self.entity:GetAngles(), true)
				end
			end
		end
		
		return NULL
	end
	
	__e2setcost(25)
	e2function entity gameCameraCreate(camera_index, vector position, angle angle)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		--only allow the game constructor to make cameras
		if is_constructor then
			local camera_count = game_camera_counts[master_index]
			
			--enforce a limit
			if not camera_count or camera_count < game_max_cameras then
				local angle = normalized_angle(angle[1], angle[2], angle[3])
				local position = clamp_to_map_bounds(position[1], position[2], position[3])
				
				if position and angle then
					--this will also check if there is an existing entity
					return camera_create(master_index, camera_index, position, angle, true)
				end
			end
		end
		
		return NULL
	end
	
	__e2setcost(5)
	e2function entity gameCameraEntity(camera_index)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor and game_cameras[master_index] then return game_cameras[master_index][camera_index] or NULL end
		
		return NULL
	end
	
	__e2setcost(8)
	e2function number gameCameraFOV(camera_index, fov)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor and game_cameras[master_index] then
			local camera = game_cameras[master_index][camera_index]
			
			if camera and ian(fov) then
				local fov = fl_math_Clamp(fov, 0, 170)
				
				camera.FOV = fov
				
				for ply_index in pairs(camera.Viewers) do fl_Player_SetFOV(Entity(ply_index), fov) end
				
				return 1
			end
		end
		
		return 0
	end
	
	__e2setcost(10)
	e2function number gameCameraLerp(camera_index, duration, vector end_position)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor and game_cameras[master_index] then
			local camera = game_cameras[master_index][camera_index]
			
			if camera then
				local end_position = clamp_to_map_bounds(end_position[1], end_position[2], end_position[3])
				local duration = fl_math_Clamp(duration, 0, game_max_camera_lerp)
				
				if duration > 0 and end_position then
					camera:NewPosLerp(duration, end_position)
					
					return 1
				end
			end
		end
		
		return 0
	end
	
	__e2setcost(12)
	e2function number gameCameraLerp(camera_index, duration, vector start_position, vector end_position)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor and game_cameras[master_index] then
			local camera = game_cameras[master_index][camera_index]
			
			if camera then
				local end_position = clamp_to_map_bounds(end_position[1], end_position[2], end_position[3])
				local start_position = clamp_to_map_bounds(start_position[1], start_position[2], start_position[3])
				local duration = fl_math_Clamp(duration, 0, game_max_camera_lerp)
				
				if duration > 0 and end_position and start_position then
					camera:NewPosLerp(duration, end_position, start_position)
					
					return 1
				end
			end
		end
		
		return 0
	end
	
	__e2setcost(16)
	e2function number gameCameraLerpBezier(camera_index, duration, vector control_position, vector end_position)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor and game_cameras[master_index] then
			local camera = game_cameras[master_index][camera_index]
			
			if camera then
				local control_position = clamp_to_map_bounds(control_position[1], control_position[2], control_position[3])
				local duration = fl_math_Clamp(duration, 0, game_max_camera_lerp)
				local end_position = clamp_to_map_bounds(end_position[1], end_position[2], end_position[3])
				
				if duration > 0 and control_position and end_position then
					camera:NewPosBezierLerp(duration, end_position, control_position)
					
					return 1
				end
			end
		end
		
		return 0
	end
	
	__e2setcost(18)
	e2function number gameCameraLerpBezier(camera_index, duration, vector start_position, vector control_position, vector end_position)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor and game_cameras[master_index] then
			local camera = game_cameras[master_index][camera_index]
			
			if camera then
				local control_position = clamp_to_map_bounds(control_position[1], control_position[2], control_position[3])
				local duration = fl_math_Clamp(duration, 0, game_max_camera_lerp)
				local end_position = clamp_to_map_bounds(end_position[1], end_position[2], end_position[3])
				local start_position = clamp_to_map_bounds(start_position[1], start_position[2], start_position[3])
				
				if duration > 0 and control_position and end_position and start_position then
					camera:NewPosBezierLerp(duration, end_position, control_position, start_position)
					
					return 1
				end
			end
		end
		
		return 0
	end
	
	__e2setcost(6)
	e2function number gameCameraParent(camera_index, entity parent)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor and game_cameras[master_index] and IsValid(parent) then
			local camera = game_cameras[master_index][camera_index]
			
			if camera and camera ~= parent and parent:GetClass() ~= "gmod_wire_game_core_camera" then
				camera:SetParent(parent)
				
				return 1
			end
		end
		
		return 0
	end
	
	__e2setcost(8)
	e2function number gameCameraPos(camera_index, vector position)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor and game_cameras[master_index] then
			local camera = game_cameras[master_index][camera_index]
			
			if camera then
				local position = clamp_to_map_bounds(position[1], position[2], position[3])
				
				if position then
					camera:SetPos(position)
					
					--stop the pos lerp if there is one, we want the check so we don't network unchanged values if there is none
					if camera:GetPosLerping() then camera:SetPosLerping(false) end
					
					return 1
				end
			end
		end
		
		return 0
	end
	
	__e2setcost(6)
	e2function number gameCameraRemove(camera_index)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor and game_cameras[master_index] then
			local camera = game_cameras[master_index][camera_index]
			
			if camera then
				camera:Remove()
				
				return 1
			end
		end
		
		return 0
	end
	
	__e2setcost(15)
	e2function number gameCameraRemoveAll()
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor and game_cameras[master_index] then
			camera_remove_all(master_index)
			
			return 1
		end
		
		return 0
	end
	
	__e2setcost(5)
	e2function number gameCameraUnparent(camera_index)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor and game_cameras[master_index] and IsValid(parent) then
			local camera = game_cameras[master_index][camera_index]
			
			if camera then
				camera:SetParent()
				
				return 1
			end
		end
		
		return 0
	end
end

--SwitchToDefaultWeapon
do --game management
	do --collidables
		--we might want to make this function part of the player functions
		__e2setcost(6)
		e2function number entity:gamePlayerCollidableSet(number state)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor and IsValid(this) then
				if this:IsPlayer() then return 0 end
				
				if owned_by_master(self, this) then
					state = state ~= 0 or nil
					
					if game_collidables[master_index] ~= state then
						local this_index = this:EntIndex()
						
						add_collidable_sync_request(master_index, this_index, state)
						
						--might need to be done on the entity with custom collisions...
						if state then
							this:CallOnRemove("wire_game_core_collidables", function(entity)
								add_collidable_sync_request(master_index, this_index)
								entity:CollisionRulesChanged()
								
								if game_collidables[master_index] then game_collidables[master_index][this_index] = nil end
								if table.IsEmpty(game_collidables[master_index]) then game_collidables[master_index] = nil end
							end)
						else this:RemoveCallOnRemove("wire_game_core_collidables") end
						
						this:CollisionRulesChanged()
						
						if game_collidables[master_index] then
							game_collidables[master_index][this_index] = state
							
							if table.IsEmpty(game_collidables[master_index]) then game_collidables[master_index] = nil end
						elseif state then game_collidables[master_index] = {[this_index] = state} end
						
						return 1
					end
				end
			end
			
			return 0
		end
	end
	
	do --management
		__e2setcost(10)
		e2function number gameClose()
			local chip_index = self.entity:EntIndex()
			local master_index = self.player:EntIndex()
			
			if game_constructor[master_index] then
				game_set_closed(master_index)
				
				return 1
			end
			
			return 0
		end

		__e2setcost(5)
		e2function number gameOpen()
			local chip_index = self.entity:EntIndex()
			local master_index = self.player:EntIndex()
			
			if game_constructor[master_index] then return 0 end
			
			--the game can be opened when game_settings is not created
			--this happens when another e2 closes the game after this e2 is constructed but before the game opens... interesting
			--this can be done by spawning an e2 when one is queued for upload
			if not game_settings[master_index] then construct_game_settings(master_index) end
			
			game_constructor[chip_index] = master_index
			game_constructor[master_index] = chip_index
			
			add_sync_request(master_index)
			
			return 1
		end
		
		__e2setcost(25)
		e2function number gamePlayerRemove()
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				game_remove_all(master_index, true)
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(10)
		e2function number entity:gamePlayerRemove()
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				game_remove(this, game_constants.LEAVE_REMOVED)
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(5)
		e2function array gamePlayers()
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				local plys = {}
				
				game_function_players(master_index, function(ply, ply_index) table.insert(plys, ply) end)
				
				return plys
			end
			
			return {}
		end
		
		__e2setcost(10)
		e2function number entity:gameRequest()
			if IsValid(this) and this:IsPlayer() then
				local chip_index = self.entity:EntIndex()
				local master = self.player
				local master_index = master:EntIndex()
				local ply_index = this:EntIndex()
				
				--only let the chip that opened the game make requests, also makes it so we can't request when there is not game
				if game_constructor[master_index] ~= chip_index then return game_constants.REQUEST_GAMELESS end
				
				if game_masters[ply_index] then
					if game_masters[ply_index] == master_index then return game_constants.REQUEST_ESTABLISHED
					else return game_constants.REQUEST_ESTABLISHED_OTHER end
				end
				
				if game_blocks[ply_index] and game_blocks[ply_index][master_index] then return game_constants.REQUEST_BLOCKED end
				if game_request_delays[master_index] and game_request_delays[master_index][ply_index] then return game_constants.REQUEST_LIMITED end
				
				--if they're a bot, and the master is an admin, force the bot into the game
				if this:IsBot() and master:IsAdmin() then
					game_add(this, master_index)
					
					--works for bots without an infinite loop, I hope
					if run_game_joins[entity] then game_function_execute(entity, {game_join_run = ply}) end
				end
				
				--we made it, now time to send the request
				if queue_game_requests[ply_index] then queue_game_requests[ply_index][master_index] = true
				else
					queue_game_requests[ply_index] = {[master_index] = true}
					queue_game_requests_check = true
				end
				
				--then make the delay
				--if the owner makes the request we will just put them into the game and return game_constants.RESPONSE_ACCEPT_FORCED
				if game_request_delays[master_index] then game_request_delays[master_index][ply_index] = CurTime() + 5
				else game_request_delays[master_index] = {[ply_index] = CurTime() + 5} end
				
				--finally, register that the chip actually made a request for the player to join
				--we need this so players with cheats can't respond to a request that was never made, yes someone did this to get into games without a request
				game_settings[master_index].requests[ply_index] = true
				
				return game_constants.REQUEST_SENT
				
			else return game_constants.REQUEST_INVALID_TARGET end
			
			return game_constants.REQUEST_UNKNOWN
		end
		
		__e2setcost(4)
		e2function number gameSetDescription(string description)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor and not game_describe_delay[master_index] then
				add_sync_request(master_index, "description")
				
				game_describe_delay[master_index] = CurTime() + game_description_delay
				game_settings[master_index].description = string.sub(description, 1, 1024)
				
				return 1
			end
			
			return 0
		end
		
		e2function number gameSetJoinable(joinable)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				add_sync_request(master_index, "open")
				
				game_settings[master_index].open = joinable ~= 0 and true or false
				
				return 1
			end
			
			return 0
		end
		
		e2function number gameSetTitle(string title)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				add_sync_request(master_index, "title")
				
				game_settings[master_index].title = string.sub(title, 1, 64)
				
				return 1
			end
			
			return 0
		end
	end
	
	do --tags
		__e2setcost(2)
		e2function number gameTagAdd(tag_id)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				local tag_id = math.Round(tag_id)
				
				if tag_id > 0 and tag_id <= tag_count and not game_settings[master_index].tags[tag_id] then
					add_sync_request(master_index, "tags")
					
					game_settings[master_index].tags[tag_id] = true
				end
				
				return 1
			end
			
			return 0
		end
		
		e2function number gameTagRemove(tag_id)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				local tag_id = math.Round(tag_id)
				
				if tag_id > 0 and tag_id <= tag_count and game_settings[master_index].tags[tag_id] then
					add_sync_request(master_index, "tags")
					
					game_settings[master_index].tags[tag_id] = nil
				end
				
				return 1
			end
			
			return 0
		end
		
		e2function number gameTagSet(tag_id, enabled)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				local tag_id = math.Round(tag_id)
				
				if tag_id > 0 and tag_id <= tag_count and game_settings[master_index].tags[tag_id] then
					add_sync_request(master_index, "tags")
					
					game_settings[master_index].tags[tag_id] = enabled ~= 0 and true or nil
				end
				
				return 1
			end
			
			return 0
		end
	end
	
	do --toggles
		__e2setcost(2)
		e2function number gameEnableFallDamage(enabled)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				game_settings[master_index].block_fall_damage = enabled == 0 and true or false
				
				return 1
			end
			
			return 0
		end

		e2function number gameEnableSuicide(enabled)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				game_settings[master_index].block_suicide = enabled == 0 and true or false
				
				return 1
			end
			
			return 0
		end
		
		e2function number gameEnablePlayerCollision(enabled)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				game_settings[master_index].ply_collide = enabled == 0 and true or false
				
				--we might want to make it so this can't be changed while players are in game
				add_sync_request(master_index, "ply_collide")
				game_function_players(master_index, function(ply) ply:CollisionRulesChanged() end)
				
				return 1
			end
			
			return 0
		end
	end
	
	do --returns
		
		__e2setcost(1)
		e2function number gameDescriptionDelay() return game_description_delay end
		e2function number gameMessageMax() return game_max_messages end
		e2function number gameMessageMaxComponents() return game_max_message_components end
		e2function number gameMessageMaxLength() return game_max_message_length end
		
		__e2setcost(4)
		e2function number gamePlayerCount()
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then return table.Count(game_settings[master_index].plys) end
			
			return -1
		end
		
		__e2setcost(5)
		e2function number entity:gamePlayerCount()
			if IsValid(this) and this.context then
				local is_constructor, chip_index, master_index = game_evaluator_constructor_only(this.context)
				
				if master_index then return table.Count(game_settings[master_index].plys) end
			end
			
			return -1
		end
		
		__e2setcost(5)
		e2function array gamePlayersAlive()
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				local plys = {}
				
				game_function_players(master_index, function(ply, ply_index) if ply:Alive() then table.insert(plys, ply) end end)
				
				return plys
			end
			
			return {}
		end
		
		__e2setcost(5)
		e2function array gamePlayersDead()
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				local plys = {}
				
				game_function_players(master_index, function(ply, ply_index) if not ply:Alive() then table.insert(plys, ply) end end)
				
				return plys
			end
			
			return {}
		end
	end
end

do --player defaults
	__e2setcost(2)
	e2function number gameSetDefaultArmor(armor)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.armor = fl_math_Clamp(armor, 0, game_max_armor)
			
			return 1
		end
		
		return 0
	end
	
	e2function number gameSetDefaultCrouchSpeedMultiplier(multiplier)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.crouch_speed = fl_math_Clamp(multiplier, 0, 1)
			
			return 1
		end
		
		return 0
	end
	
	e2function number gameSetDefaultDamageDealtMultiplier(multiplier)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.damage_dealt = fl_math_Clamp(multiplier, 0, game_max_damage_multiplier)
			
			return 1
		end
		
		return 0
	end
	
	e2function number gameSetDefaultDamageTakenMultiplier(multiplier)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.damage_taken = fl_math_Clamp(multiplier, 0, game_max_damage_multiplier)
			
			return 1
		end
		
		return 0
	end
	
	e2function number gameSetDefaultFlashlight(enabled)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.flashlight = enabled ~= 0 and true or false
			
			return 1
		end
		
		return 0
	end
	
	e2function number gameSetDefaultGravity(multiplier)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.gravity = fl_math_Clamp(multiplier, -10, 10)
			
			return 1
		end
		
		return 0
	end
	
	e2function number gameSetDefaultHealth(health)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.health = fl_math_Clamp(health, 1, 1000)
			
			return 1
		end
		
		return 0
	end
	
	e2function number gameSetDefaultJumpPower(power)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.jump_power = fl_math_Clamp(power, 0, 1024)
			
			return 1
		end
		
		return 0
	end
	
	e2function number gameSetDefaultLadderSpeed(speed)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.ladder_speed = fl_math_Clamp(speed, 0, game_max_speed)
			
			return 1
		end
		
		return 0
	end
	
	e2function number gameSetDefaultMaxHealth(max)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.max_health = fl_math_Clamp(max, 1, 1000)
			
			return 1
		end
		
		return 0
	end
	
	e2function number gameSetDefaultMaxArmor(max)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.max_armor = fl_math_Clamp(max, 1, 1000)
			
			return 1
		end
		
		return 0
	end
	
	e2function number gameSetDefaultRespawnDelay(delay)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor and ian(delay) then
			game_settings[master_index].defaults.respawn_delay = fl_math_Clamp(delay, 0.1, 60)
			
			return 1
		end
		
		return 0
	end
	
	e2function number gameSetDefaultRespawnMode(enum)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.respawn_mode = enum > 0 and enum < 5 and enum or 2
			
			return 1
		end
		
		return 0
	end
	
	e2function number gameSetDefaultRunSpeed(speed)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.run_speed = fl_math_Clamp(speed, 0, game_max_speed)
			
			return 1
		end
		
		return 0
	end
	
	e2function number gameSetDefaultSpeed(speed)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.walk_speed = fl_math_Clamp(speed, 0, game_max_speed)
			
			return 1
		end
		
		return 0
	end
	
	e2function number gameSetDefaultWalkSpeed(speed)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.stroll_speed = fl_math_Clamp(speed, 0, game_max_speed)
			
			return 1
		end
		
		return 0
	end
end

do --game management
	do --camera
		__e2setcost(6)
		e2function number entity:gamePlayerSetCamera()
			local is_participating, ply_index, chip_index, master_index = game_evaluator_player_only(self, this)
			
			if is_participating and game_cameras[master_index] then
				local camera_index = ply_cameras[ply_index]
				
				--we don't check for a valid camera inside the function, so we have to check before we run it
				if camera_index and game_cameras[master_index][camera_index] then
					camera_disable(this, ply_index, master_index)
					
					return 1
				end
			end
			
			return 0
		end
		
		__e2setcost(8)
		e2function number entity:gamePlayerSetCamera(camera_index)
			local is_participating, ply_index, chip_index, master_index = game_evaluator_player_only(self, this)
			
			--we don't check for a valid camera inside the function, so we have to check before we run it
			if is_participating and game_cameras[master_index] and game_cameras[master_index][camera_index] then
				camera_enable(this, ply_index, master_index, camera_index)
				
				return 1
			end
			
			return 0
		end
	end
	
	do --damage, and respawn
		__e2setcost(12)
		e2function number gamePlayerKill()
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				game_function_players(master_index, function(ply) if ply:Alive() then ply:Kill() end end)
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(5)
		e2function number entity:gamePlayerKill()
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating and this:Alive() then
				this:Kill()
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(20)
		e2function number gamePlayerRespawn()
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				game_function_players(master_index, function(ply) ply:Spawn() end)
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(8)
		e2function number entity:gamePlayerRespawn()
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				this:Spawn()
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(7)
		e2function number gamePlayerSetDamageDealtMultiplier(multiplier)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_participating then
				if multiplier == 1 then game_function_players(master_index, function(ply, ply_index) game_damage_dealt[ply_index] = nil end)
				else
					multiplier = fl_math_Clamp(multiplier, 0, 1000)
					
					game_function_players(master_index, function(ply, ply_index) game_damage_dealt[ply_index] = multiplier end)
				end
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(3)
		e2function number entity:gamePlayerSetDamageDealtMultiplier(multiplier)
			local is_participating, ply_index = game_evaluator_player_only(self, this)
			
			if is_participating then
				if multiplier == 1 then game_damage_dealt[ply_index] = nil
				else game_damage_dealt[ply_index] = fl_math_Clamp(multiplier, 0, 1000) end
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(7)
		e2function number gamePlayerSetDamageTakenMultiplier(multiplier)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_participating then
				if multiplier == 1 then game_function_players(master_index, function(ply, ply_index) game_damage_taken[ply_index] = nil end)
				else
					multiplier = fl_math_Clamp(multiplier, 0, 1000)
					
					game_function_players(master_index, function(ply, ply_index) game_damage_taken[ply_index] = multiplier end)
				end
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(3)
		e2function number entity:gamePlayerSetDamageTakenMultiplier(multiplier)
			local is_participating, ply_index = game_evaluator_player_only(self, this)
			
			if is_participating then
				if multiplier == 1 then game_damage_taken[ply_index] = nil
				else game_damage_taken[ply_index] = fl_math_Clamp(multiplier, 0, 1000) end
				
				return 1
			end
			
			return 0
		end
	end
	
	do --health
		__e2setcost(10)
		e2function number gamePlayerSetArmor(amount)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				amount = fl_math_Clamp(amount, 0, game_max_armor)
				
				game_function_players(master_index, function(ply) fl_Player_SetArmor(ply, amount) end)
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(4)
		e2function number entity:gamePlayerSetArmor(amount)
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				fl_Player_SetArmor(this, fl_math_Clamp(amount, 0, game_max_armor))
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(10)
		e2function number gamePlayerSetHealth(amount)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				amount = fl_math_Clamp(amount, 1, game_max_health)
				
				game_function_players(master_index, function(ply) fl_Entity_SetHealth(ply, amount) end)
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(4)
		e2function number entity:gamePlayerSetHealth(amount)
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				fl_Entity_SetHealth(this, fl_math_Clamp(amount, 1, game_max_health))
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(10)
		e2function number gamePlayerSetMaxArmor(amount)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				amount = fl_math_Clamp(amount, 1, game_max_health)
				
				game_function_players(master_index, function(ply) fl_Player_SetMaxArmor(ply, amount) end)
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(4)
		e2function number entity:gamePlayerSetMaxArmor(amount)
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				fl_Player_SetMaxArmor(this, fl_math_Clamp(amount, 0, game_max_health))
				
				return 1
			end
			
			return 0
		end
		__e2setcost(10)
		e2function number gamePlayerSetMaxHealth(amount)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				amount = fl_math_Clamp(amount, 1, game_max_health)
				
				game_function_players(master_index, function(ply) fl_Entity_SetMaxHealth(ply, amount) end)
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(4)
		e2function number entity:gamePlayerSetMaxHealth(amount)
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				fl_Entity_SetMaxHealth(this, fl_math_Clamp(amount, 0, game_max_health))
				
				return 1
			end
			
			return 0
		end
	end
	
	do --physics
		__e2setcost(12)
		e2function number entity:gamePlayerApplyForce(vector force)
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				local force = clamped_magnitude(force[1], force[2], force[3], game_max_force)
				
				if force then
					this:SetVelocity(force)
					
					return 1
				end
			end
			
			return 0
		end
		
		__e2setcost(10)
		e2function number entity:gamePlayerSetAng(angle angle)
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				local angle = normalized_angle(angle[1], angle[2], angle[3])
				
				if angle then
					fl_Player_SetEyeAngles(this, angle)
					
					return 1
				end
			end
			
			return 0
		end
		
		__e2setcost(12)
		e2function number entity:gamePlayerSetPos(vector position)
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				local position = clamp_to_map_bounds(position[1], position[2], position[3])
				
				if position then
					fl_Entity_SetPos(this, position)
					
					return 1
				end
			end
			
			return 0
		end
	end
	
	do --messaging
		__e2setcost(12)
		e2function number entity:gamePlayerMessage(notification_duration, ...)
			local is_participating, ply_index, chip_index, master_index = game_evaluator_player_only(self, this)
			
			if is_participating then
				local message_table = parse_message(typeids, ...)
				
				if table.IsEmpty(message_table) then return 0 end
				
				local count = game_message_counts[ply_index] or 0
				
				if count < game_max_messages then
					if count > 0 then game_message_counts[ply_index] = count + 1
					else
						game_message_counts[ply_index] = 1
						game_message_resets[ply_index] = CurTime() + 1
					end
					
					game_write_message(message_table, true, notification_duration)
					net.Send(this)
				end
			end
			
			return 1
		end
		
		e2function number entity:gamePlayerMessage(notification_duration, new_line, ...)
			local is_participating, ply_index, chip_index, master_index = game_evaluator_player_only(self, this)
			
			if is_participating then
				local message_table = parse_message(typeids, ...)
				
				if table.IsEmpty(message_table) then return 0 end
				
				local count = game_message_counts[ply_index] or 0
				
				if count < game_max_messages then
					if count > 0 then game_message_counts[ply_index] = count + 1
					else
						game_message_counts[ply_index] = 1
						game_message_resets[ply_index] = CurTime() + 1
					end
					
					game_write_message(message_table, new_line ~= 0, notification_duration)
					net.Send(this)
				end
			end
			
			return 1
		end
		
		--can we do net.ReadTable when there is no table?
		__e2setcost(8)
		e2function number entity:gamePlayerMessageClear()
			local is_participating, ply_index, chip_index, master_index = game_evaluator_player_only(self, this)
			
			if is_participating then
				local count = game_message_counts[ply_index] or 0
				
				if count < game_max_messages then
					if count > 0 then game_message_counts[ply_index] = count + 1
					else
						game_message_counts[ply_index] = 1
						game_message_resets[ply_index] = CurTime() + 1
					end
					
					game_write_message()
					net.Send(this)
				end
			end
			
			return 1
		end
		
		__e2setcost(30)
		e2function number gamePlayerMessage(notification_duration, ...)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				local message_table = parse_message(typeids, ...)
				
				if table.IsEmpty(message_table) then return 0 end
				
				local filter = RecipientFilter()
				local reset_time = CurTime() + 1
				local send = false
				
				game_function_players(master_index, function(ply, ply_index)
					local count = game_message_counts[ply_index] or 0
					
					if count < game_max_messages then
						if count > 0 then game_message_counts[ply_index] = count + 1
						else
							game_message_counts[ply_index] = 1
							game_message_resets[ply_index] = reset_time
						end
						
						send = true
						
						filter:AddPlayer(ply)
					end
				end)
				
				if send then
					game_write_message(message_table, true, notification_duration)
					net.Send(filter)
					
					return 1
				end
			end
			
			return 0
		end
		
		e2function number gamePlayerMessage(notification_duration, new_line, ...)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				local message_table = parse_message(typeids, ...)
				
				if table.IsEmpty(message_table) then return 0 end
				
				local filter = RecipientFilter()
				local reset_time = CurTime() + 1
				local send = false
				
				game_function_players(master_index, function(ply, ply_index)
					local count = game_message_counts[ply_index] or 0
					
					if count < game_max_messages then
						if count > 0 then game_message_counts[ply_index] = count + 1
						else
							game_message_counts[ply_index] = 1
							game_message_resets[ply_index] = reset_time
						end
						
						send = true
						
						filter:AddPlayer(ply)
					end
				end)
				
				if send then
					game_write_message(message_table, new_line ~= 0, notification_duration)
					net.Send(filter)
					
					return 1
				end
			end
			
			return 0
		end
		
		__e2setcost(20)
		e2function number gamePlayerMessageClear()
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				local filter = RecipientFilter()
				local reset_time = CurTime() + 1
				local send = false
				
				game_function_players(master_index, function(ply, ply_index)
					local count = game_message_counts[ply_index] or 0
					
					if count < game_max_messages then
						if count > 0 then game_message_counts[ply_index] = count + 1
						else
							game_message_counts[ply_index] = 1
							game_message_resets[ply_index] = reset_time
						end
						
						send = true
						
						filter:AddPlayer(ply)
					end
				end)
				
				if send then
					game_write_message()
					net.Send(filter)
					
					return 1
				end
			end
			
			return 0
		end
		
		--can send message
		e2function number entity:gameMessageCanSend()
			local is_participating, ply_index, chip_index, master_index = game_evaluator_player_only(self, this)
			
			if is_participating then return (game_message_counts[ply_index] or 0) < game_max_messages end
			
			return 0
		end
	end
	
	do --movement
		__e2setcost(10)
		e2function number gamePlayerSetCrouchSpeedMultiplier(multiplier)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				multiplier = fl_math_Clamp(multiplier, 0, 1)
				
				game_function_players(master_index, function(ply) fl_Player_SetCrouchedWalkSpeed(ply, multiplier) end)
				
				return 1
			end
			
			return 0
		end

		e2function number entity:gamePlayerSetJumpPower(power)
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				local power = fl_math_Clamp(power, 0, 1024)
				
				game_function_players(master_index, function(ply) fl_Player_SetJumpPower(this, power) end)
				
				return 1
			end
			
			return 0
		end
		
		e2function number gamePlayerSetLadderSpeed(speed)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				local speed = fl_math_Clamp(speed, 0, game_max_speed)
				
				game_function_players(master_index, function(ply) fl_Player_SetLadderClimbSpeed(ply, speed) end)
				
				return 1
			end
			
			return 0
		end
		
		e2function number gamePlayerSetRunSpeed(speed)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				local speed = fl_math_Clamp(speed, 0, game_max_speed)
				
				game_function_players(master_index, function(ply) fl_Player_SetRunSpeed(ply, speed) end)
				
				return 1
			end
			
			return 0
		end
		
		e2function number gamePlayerSetSpeed(speed)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				local speed = fl_math_Clamp(speed, 0, game_max_speed)
				
				game_function_players(master_index, function(ply) fl_Player_SetWalkSpeed(ply, speed) end)
				
				return 1
			end
			
			return 0
		end
		
		e2function number gamePlayerSetWalkSpeed(speed)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				local speed = fl_math_Clamp(speed, 0, game_max_speed)
				
				game_function_players(master_index, function(ply) fl_Player_SetSlowWalkSpeed(ply, speed) end)
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(4)
		e2function number entity:gamePlayerSetCrouchSpeedMultiplier(multiplier)
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				fl_Player_SetCrouchedWalkSpeed(this, fl_math_Clamp(multiplier, 0, 1))
				
				return 1
			end
			
			return 0
		end
		
		e2function number entity:gamePlayerSetJumpPower(power)
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				fl_Player_SetJumpPower(this, fl_math_Clamp(power, 0, 1024))
				
				return 1
			end
			
			return 0
		end
		
		e2function number entity:gamePlayerSetLadderSpeed(speed)
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				fl_Player_SetLadderClimbSpeed(this, fl_math_Clamp(speed, 0, game_max_speed))
				
				return 1
			end
			
			return 0
		end
		
		e2function number entity:gamePlayerSetRunSpeed(speed)
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				fl_Player_SetRunSpeed(this, fl_math_Clamp(speed, 0, game_max_speed))
				
				return 1
			end
			
			return 0
		end
		
		e2function number entity:gamePlayerSetSpeed(speed)
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				fl_Player_SetWalkSpeed(this, fl_math_Clamp(speed, 0, game_max_speed))
				
				return 1
			end
			
			return 0
		end
		
		e2function number entity:gamePlayerSetWalkSpeed(speed)
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				fl_Player_SetSlowWalkSpeed(this, fl_math_Clamp(speed, 0, game_max_speed))
				
				return 1
			end
			
			return 0
		end
	end
	
	do --sound
		__e2setcost(20)
		e2function number gamePlayerPlaySound(string sound_path)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				local sound_path_truncated = string.sub(sound_path, 1, 192)
				
				--keep the exploiters away
				if string.match(sound_path_truncated, '["?]') then return 0 end
				
				game_function_players(master_index, function(ply, ply_index)
					if not queue_game_sounds[ply_index] then queue_game_sounds[ply_index] = {} end
					if #queue_game_sounds[ply_index] < queue_game_sounds_max then
						queue_game_sounds_check = true
						
						table.insert(queue_game_sounds[ply_index], sound_path_truncated)
					end
				end)
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(6)
		e2function number entity:gamePlayerPlaySound(string sound_path)
			local is_participating, ply_index = game_evaluator_player_only(self, this)
			
			if is_participating then
				if not queue_game_sounds[ply_index] then queue_game_sounds[ply_index] = {} end
				
				if #queue_game_sounds[ply_index] < queue_game_sounds_max then
					local sound_path_truncated = string.sub(sound_path, 1, 192)
					
					--keep the exploiters away
					if string.match(sound_path_truncated, '["?]') then return 0 end
					
					queue_game_sounds_check = true
					
					table.insert(queue_game_sounds[ply_index], sound_path_truncated)
					
					return 1
				end
			end
			
			return 0
		end
	end
	
	do --strip
		__e2setcost(10)
		e2function number gamePlayerStripAmmo()
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				for ply_index in pairs(game_settings[master_index].plys) do fl_Player_StripAmmo(Entity(ply_index)) end
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(4)
		e2function number entity:gamePlayerStripAmmo()
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				fl_Player_StripAmmo(this)
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(25)
		e2function number gamePlayerStripEverything()
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				for ply_index in pairs(game_settings[master_index].plys) do
					local ply = Entity(ply_index)
					
					fl_Player_StripAmmo(ply)
					fl_Player_StripWeapons(ply)
				end
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(10)
		e2function number entity:gamePlayerStripEverything()
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				fl_Player_StripAmmo(this)
				fl_Player_StripWeapons(this)
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(15)
		e2function number gamePlayerStripWeapon()
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				for ply_index in pairs(game_settings[master_index].plys) do fl_Player_StripWeapons(Entity(ply_index)) end --use undetoured
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(7)
		e2function number gamePlayerStripWeapon(string weapon_class)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				for ply_index in pairs(game_settings[master_index].plys) do fl_Player_StripWeapons(Entity(ply_index)) end  --use undetoured
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(6)
		e2function number entity:gamePlayerStripWeapon()
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				fl_Player_StripWeapons(this)
				
				return 1
			end
			
			return 0
		end
		
		__e2setcost(3)
		e2function number entity:gamePlayerStripWeapon(string weapon_class)
			local is_participating = game_evaluator_player_only(self, this)
			
			if is_participating then
				this:StripWeapon(weapon_class) --use undetoured
				
				return 1
			end
			
			return 0
		end
	end
	
	do --weapons, ammo, clip
		do --ammo
			__e2setcost(4)
			e2function number entity:gamePlayerGiveAmmo(string ammo_type, amount)
				local is_participating = game_evaluator_player_only(self, this)
				
				if is_participating then
					fl_Player_GiveAmmo(this, amount, ammo_type)
					
					return 1
				end
				
				return 0
			end
			
			e2function number entity:gamePlayerGiveAmmo(string ammo_type, amount, show_pop_up)
				local is_participating = game_evaluator_player_only(self, this)
				
				if is_participating then
					fl_Player_GiveAmmo(this, amount, ammo_type, show_pop_up == 0)
					
					return 1
				end
				
				return 0
			end
		end
		
		do --clip
			__e2setcost(10)
			e2function number gamePlayerSetClip1(string weapon_class, amount)
				local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
				
				if is_constructor then
					game_function_players(master_index, function(ply)
						local weapon = ply:GetWeapon(weapon_class)
						
						if IsValid(weapon) then weapon:SetClip1(amount) end
					end)
					
					return 1
				end
				
				return 0
			end
			
			__e2setcost(4)
			e2function number entity:gamePlayerSetClip1(amount)
				if IsValid(this) and this:IsWeapon() then
					owner = this:GetOwner()
					
					if IsValid(owner) then
						local is_participating = game_evaluator_player_only(self, owner)
						
						if is_participating then
							this:SetClip1(amount)
							
							return 1
						end
					end
				end
				
				return 0
			end
			
			e2function number entity:gamePlayerSetClip1(string weapon_class, amount)
				local is_participating = game_evaluator_player_only(self, this)
				
				if is_participating then
					local weapon = this:GetWeapon(weapon_class)
					
					if IsValid(weapon) then
						weapon:SetClip1(amount)
						
						return 1
					end
				end
				
				return 0
			end
			
			__e2setcost(10)
			e2function number gamePlayerSetClip2(string weapon_class, amount)
				local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
				
				if is_constructor then
					game_function_players(master_index, function(ply)
						local weapon = ply:GetWeapon(weapon_class)
						
						if IsValid(weapon) then weapon:SetClip2(amount) end
					end)
					
					return 1
				end
				
				return 0
			end
			
			__e2setcost(4)
			e2function number entity:gamePlayerSetClip2(amount)
				if IsValid(this) and this:IsWeapon() then
					owner = this:GetOwner()
					
					if IsValid(owner) then
						local is_participating = game_evaluator_player_only(self, owner)
						
						if is_participating then
							this:SetClip2(amount)
							
							return 1
						end
					end
				end
				
				return 0
			end
			
			e2function number entity:gamePlayerSetClip2(string weapon_class, amount)
				local is_participating = game_evaluator_player_only(self, this)
				
				if is_participating then
					local weapon = this:GetWeapon(weapon_class)
					
					if IsValid(weapon) then
						weapon:SetClip2(amount)
						
						return 1
					end
				end
				
				return 0
			end
		end
		
		do --weapons
			__e2setcost(25)
			e2function array gamePlayerGiveWeapon(string weapon_class)
				local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
				
				if is_constructor then
					local return_array = {}
					
					game_function_players(master_index, function(ply)
						local weapon = give_weapon(ply, Entity(master_index), weapon_class, true)
						
						--garunteed to give an entity, null or not, no need to use the global as the method sohuld work fine
						if weapon:IsValid() then table.insert(return_array, weapon) end
					end)
					
					return return_array
				end
				
				return {}
			end
			
			e2function array gamePlayerGiveWeapon(string weapon_class, give_ammo)
				local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
				
				if is_constructor then
					local give_ammo = give_ammo == 0
					local return_array = {}
					
					game_function_players(master_index, function(ply)
						local weapon = give_weapon(ply, Entity(master_index), weapon_class, give_ammo)
						
						--garunteed to give an entity, null or not, no need to use the global as the method sohuld work fine
						if weapon:IsValid() then table.insert(return_array, weapon) end
					end)
					
					return return_array
				end
				
				return {}
			end
			
			__e2setcost(10)
			e2function entity entity:gamePlayerGiveWeapon(string weapon_class)
				local is_participating, ply_index, chip_index, master_index = game_evaluator_player_only(self, this)
				
				if is_participating then return give_weapon(this, Entity(master_index),  weapon_class, true) end
				
				return NULL
			end
			
			e2function entity entity:gamePlayerGiveWeapon(string weapon_class, give_ammo)
				local is_participating, ply_index, chip_index, master_index = game_evaluator_player_only(self, this)
				
				if is_participating then return give_weapon(this, Entity(master_index), weapon_class, give_ammo == 0) end
				
				return NULL
			end
		end
	end
end

do --run functions
	do --runOnGame*(activate)
		__e2setcost(1)
		e2function void runOnGameDeath(activate)
			if activate ~= 0 then run_game_deaths[self.entity] = true
			else run_game_deaths[self.entity] = nil end
		end
		
		e2function void runOnGameJoin(activate)
			if activate ~= 0 then run_game_joins[self.entity] = true
			else run_game_joins[self.entity] = nil end
		end
		
		e2function void runOnGameLeave(activate)
			if activate ~= 0 then run_game_leave[self.entity] = true
			else run_game_leave[self.entity] = nil end
		end
		
		e2function void runOnGameRequestResponse(activate)
			if activate ~= 0 then run_game_requests[self.entity] = true
			else run_game_requests[self.entity] = nil end
		end
		
		e2function void runOnGameRespawn(activate)
			if activate ~= 0 then run_game_respawns[self.entity] = true
			else run_game_respawns[self.entity] = nil end
		end
	end
	
	do --game*Clk()
		__e2setcost(3)
		e2function entity gameDeathClk()
			local ply = self.data.game_death_run
			
			return IsValid(ply) and ply or NULL
		end
		
		e2function entity gameJoinClk()
			local ply = self.data.game_join_run
			
			return IsValid(ply) and ply or NULL
		end
		
		__e2setcost(1)
		e2function number gameLeaveClk() return self.data.game_leave_run or 0 end
		
		__e2setcost(1)
		e2function number gameRequestResponseClk() return self.data.game_request_run or 0 end
		
		__e2setcost(3)
		e2function entity gameRespawnClk()
			local ply = self.data.game_respawn_run
			
			return IsValid(ply) and ply or NULL
		end
	end
	
	do --game**()
		__e2setcost(3)
		e2function entity gameDeathAttacker()
			local ply = self.data.game_death_run_attacker
			
			return IsValid(ply) and ply or NULL
		end
		
		e2function entity gameDeathInflictor()
			local ply = self.data.game_death_run_inflictor 
			
			return IsValid(ply) and ply or NULL
		end
		
		e2function entity gameLeavePlayer()
			local ply = self.data.game_leave_run_ply
			
			return IsValid(ply) and ply or NULL
		end
		
		e2function entity gameRequestResponsePlayer()
			local ply = self.data.game_request_run_ply
			
			return IsValid(ply) and ply or NULL
		end
	end
end

--callbacks
registerCallback("construct",
	function(self)
		--[[local master_index = self.player:EntIndex()
		
		if master_index and not game_settings[master_index] then construct_game_settings(master_index) end]]
	end
)

registerCallback("destruct",
	function(self)
		local entity = self.entity
		local master_index = game_constructor[entity:EntIndex()]
		
		run_game_deaths[entity] = nil
		run_game_joins[entity] = nil
		run_game_leave[entity] = nil
		run_game_requests[entity] = nil
		run_game_respawns[entity] = nil
		
		if master_index then game_set_closed(master_index, true) end
	end
)

--concommand
--[[ debug
concommand.Add("wire_game_core_debug_cameras", function()
	print("Counts")
	PrintTable(game_camera_counts, 1)
	print("Entities")
	PrintTable(game_cameras, 1)
	print("Player cameras")
	PrintTable(ply_cameras, 1)
end, nil, "Debug for game core, shows info about cameras.")

concommand.Add("wire_game_core_debug_settings", function()
	print("Game masters")
	PrintTable(game_masters, 1)
	print("Game settings")
	PrintTable(game_settings, 1)
end, nil, "Debug for game core, shows info about cameras.") --]]

--convars
--use the get functions so you don't have to format the input to your liking?
cvars.AddChangeCallback("gmod_maxammo", function()
	local max = gmod_maxammo:GetInt()
	
	game_max_ammo = max ~= 0 and max or nil
end, "wire_game_core")

cvars.AddChangeCallback("wire_game_core_description_delay", function() game_description_delay = wire_game_core_description_delay:GetFloat() end)
cvars.AddChangeCallback("wire_game_core_max_armor", function() game_max_armor = wire_game_core_max_armor:GetInt() end)
cvars.AddChangeCallback("wire_game_core_max_camera_lerp", function() game_max_camera_lerp = wire_game_core_max_camera_lerp:GetFloat() end)
cvars.AddChangeCallback("wire_game_core_max_cameras", function() game_max_cameras = wire_game_core_max_cameras:GetInt() end)
cvars.AddChangeCallback("wire_game_core_max_damage_multiplier", function() game_max_damage_multiplier = wire_game_core_max_damage_multiplier:GetFloat() end)
cvars.AddChangeCallback("wire_game_core_max_description_length", function() game_max_description_length = wire_game_core_max_description_length:GetInt() end)
cvars.AddChangeCallback("wire_game_core_max_force", function() game_max_force = wire_game_core_max_force:GetFloat() end)
cvars.AddChangeCallback("wire_game_core_max_gravity", function() game_max_gravity = wire_game_core_max_gravity:GetFloat() end)
cvars.AddChangeCallback("wire_game_core_max_health", function() game_max_health = wire_game_core_max_health:GetInt() end)
cvars.AddChangeCallback("wire_game_core_max_message_components", function() game_max_message_components = wire_game_core_max_message_components:GetInt() end)
cvars.AddChangeCallback("wire_game_core_max_message_length", function() game_max_message_length = wire_game_core_max_message_length:GetInt() end)
cvars.AddChangeCallback("wire_game_core_max_messages", function() game_max_messages = wire_game_core_max_messages:GetInt() end)
cvars.AddChangeCallback("wire_game_core_max_sounds", function() queue_game_sounds_max = wire_game_core_max_sounds:GetInt() end)
cvars.AddChangeCallback("wire_game_core_max_speed", function() game_max_speed = wire_game_core_max_speed:GetFloat() end)
cvars.AddChangeCallback("wire_game_core_min_gravity", function() game_min_gravity = wire_game_core_min_gravity:GetFloat() end)
cvars.AddChangeCallback("wire_game_core_request_delay", function() game_request_delay = wire_game_core_request_delay:GetFloat() end)

--hooks
hook.Add("AllowPlayerPickup", "wire_game_core", player_can_interact)
hook.Add("CanArmDupe", "wire_game_core", active_game_inv)
hook.Add("CanDrive", "wire_game_core", active_game_inv)
hook.Add("CanPlayerEnterVehicle", "wire_game_core", player_can_interact)
hook.Add("CanProperty", "wire_game_core", active_game_inv)
hook.Add("CanTool", "wire_game_core", active_game_inv)

hook.Add("CanPlayerSuicide", "wire_game_core", function(ply)
	local master_index = game_masters[ply:EntIndex()]
	
	if master_index and game_settings[master_index].block_suicide then return false end
end)

hook.Add("EntityTakeDamage", "wire_game_core", function(victim, damage_info)
	local attacker = damage_info:GetAttacker()
	local attacker_validity = IsValid(attacker)
	local victim_index = victim:EntIndex()
	local victim_master_index = game_masters[victim_index]
	
	if victim_master_index then
		if shouldnt_damage(victim, attacker_validity and attacker or false, victim_index, attacker_validity and attacker:EntIndex() or false) then return true end
		
		damage_info:ScaleDamage(game_damage_taken[victim_index] or 1)
	end
	
	if attacker_validity then
		local attacker_index = attacker:EntIndex()
		
		if game_masters[attacker_index] then
			if shouldnt_damage(attacker, victim, attacker_index, victim_index) then return true end
			
			damage_info:ScaleDamage(game_damage_dealt[attacker_index] or 1)
		end
	end
end)

hook.Add("GetFallDamage", "wire_game_core", function(ply)
	local ply_index = ply:EntIndex()
	local master_index = game_masters[ply_index]
	
	if master_index and game_settings[master_index].block_fall_damage then return 0 end
end)

hook.Add("GravGunPickupAllowed", "wire_game_core", player_can_interact)
hook.Add("PhysgunPickup", "wire_game_core", player_can_interact)
hook.Add("PlayerCanPickupItem", "wire_game_core", player_can_interact)

hook.Add("PlayerCanPickupWeapon", "wire_game_core", function(ply, weapon)
	local master_index = game_masters[ply:EntIndex()]
	
	if master_index then
		if IsValid(weapon) then
			if weapons_passing then
				weapons_passing = false
				
				return true
			end
			
			if owned_by_master(get_context(master_index), weapon) then return true end
		end
		
		return false
	end
end)

hook.Add("PlayerDeath", "wire_game_core", function(victim, inflictor, attacker)
	local victim_index = victim:EntIndex()
	local master_index = game_masters[victim_index]
	
	if master_index then
		local entity = Entity(game_constructor[master_index])
		local defaults = game_settings[master_index].defaults
		
		if defaults.respawn_mode == game_constants.RESPAWNMODE_DELAYED then game_respawns[victim_index] = CurTime() + defaults.respawn_delay end
		
		if run_game_deaths[entity] then
			game_function_execute(entity, {
				game_death_run = victim,
				game_death_run_attacker = attacker,
				game_death_run_inflictor = inflictor
			})
		end
	end
end)

hook.Add("PlayerDisconnected", "wire_game_core", function(ply)
	--supposedly reliable now?
	local ply_index = ply:EntIndex()
	
	if game_constructor[ply_index] then game_set_closed(ply_index, true)
	elseif game_masters[ply_index] then game_remove(ply, game_constants.LEAVE_DISCONNECT) end
	
	net.Start("wire_game_core_block_update")
	net.WriteBool(false)
	net.WriteUInt(ply_index, 8)
	net.Broadcast()
end)

hook.Add("PlayerInitialSpawn", "wire_game_core", function(ply)
	--PlayerDisconnected is not reliable, this hook is (except for networking stuff, which is why we wait for the client's InitPostEntity hook to run before we sync)
	local ply_index = ply:EntIndex()
	
	game_request_delays[ply_index] = nil
	game_blocks[ply_index] = nil
	game_masters[ply_index] = nil
	game_settings[ply_index] = nil
	ply_settings[ply_index] = nil
	
	ply:SetCustomCollisionCheck(true)
	
	net.Start("wire_game_core_block_update")
	net.WriteBool(true)
	net.WriteUInt(ply_index, 8)
	net.Broadcast()
end)

hook.Add("PlayerNoClip", "wire_game_core", function(ply, desire) if game_masters[ply:EntIndex()] and desire then return false end end)

hook.Add("PlayerSpawn", "wire_game_core", function(ply)
	local ply_index = ply:EntIndex()
	local master_index = game_masters[ply_index]
	
	if master_index then
		local entity = Entity(game_constructor[master_index])
		
		game_acclimate(ply, ply_index, game_settings[master_index].defaults)
		
		if run_game_respawns[entity] then game_function_execute(entity, {game_respawn_run = ply}) end
		if ulib_spawn then ply.ULibSpawnInfo = nil end
		
		return true
	end
end)

hook.Add("PlayerGiveSWEP", "wire_game_core", active_game_inv)
hook.Add("PlayerSpawnNPC", "wire_game_core", active_game_inv)
hook.Add("PlayerSpawnObject", "wire_game_core", active_game_inv)
hook.Add("PlayerSpawnSENT", "wire_game_core", active_game_inv)
hook.Add("PlayerSpawnSWEP", "wire_game_core", active_game_inv)
hook.Add("PlayerSpawnVehicle", "wire_game_core", active_game_inv)

--fuck pac, it's so messy
hook.Add("PrePACConfigApply", "wire_game_core", function(ply, data)
	local ply_index = ply:EntIndex()
	
	if game_masters[ply_index] then return false, "You cannot wear your outfit while in a game." end
end)

--very gross
hook.Add("ShouldCollide", "wire_game_core", function(ent_1, ent_2)
	local ply = ent_1:IsPlayer() and game_masters[ent_1:EntIndex()] and ent_1 or ent_2:IsPlayer() and game_masters[ent_2:EntIndex()] and ent_2 or false
	
	if ply then
		local obstacle = ply == ent_1 and ent_2 or ent_1
		
		return should_collide(ply, obstacle, ply:EntIndex(), obstacle:EntIndex())
	end
end)

hook.Add("Think", "wire_game_core", function()
	local cur_time = CurTime()
	
	if queue_game_collidables_check then
		local passed_master_index = false
		
		net.Start("wire_game_core_collidables")
		
		for master_index, collidables in pairs(queue_game_collidables) do
			local passed_ent_index = false
			
			--say: there is another master that has entries to network
			if passed_master_index then net.WriteBool(true)
			else passed_master_index = true end
			
			--wasting two possiblities >:[ (0 and 256)
			net.WriteUInt(master_index, 8)
			
			for ent_index, collidable in pairs(collidables) do
				--say: there is another entry
				if passed_ent_index then net.WriteBool(true)
				else passed_ent_index = true end
				
				net.WriteUInt(ent_index, 13)
				net.WriteBool(collidable)
			end
			
			net.WriteBool(false) --say: there are no more entries
		end
		
		net.Broadcast()
		
		queue_game_collidables = {}
		queue_game_collidables_check = false
	end
	
	if queue_game_masters_check then
		local send = {}
		
		for ply_index in pairs(queue_game_masters) do send[ply_index] = game_masters[ply_index] or 0 end
		
		net.Start("wire_game_core_masters")
		net.WriteTable(send)
		net.Broadcast()
		
		queue_game_masters = {}
		queue_game_masters_check = false
	end
	
	if queue_game_requests_check then
		local recipients = {}
		local send = {}
		
		for recipient_index, requests in pairs(queue_game_requests) do
			local recipient = Entity(recipient_index)
			
			if IsValid(recipient) then
				for master_index in pairs(requests) do
					if IsValid(Entity(master_index)) then
						--we only want to send to players if they are valid, and if they have valid masters, send those valid masters
						if send[recipient_index] then send[recipient_index][master_index] = true
						else
							send[recipient_index] = {[master_index] = true}
							
							table.insert(recipients, recipient)
						end
					end
				end
			end
		end
		
		net.Start("wire_game_core_request")
		net.WriteTable(send)
		net.Send(recipients)
		
		queue_game_requests = {}
		queue_game_requests_check = false
	end
	
	if queue_game_sounds_check then
		for ply_index, sounds in pairs(queue_game_sounds) do
			local ply = Entity(ply_index)
			
			if IsValid(ply) then
				net.Start("wire_game_core_sounds")
				net.WriteTable(sounds)
				net.Send(ply)
			end
		end
		
		queue_game_sounds = {}
		queue_game_sounds_check = false
	end
	
	if queue_game_sync_check then
		--wonder what happens if multiple of these run? I sure hope I don't have to
		local recipients = {}
		local send = {}
		
		for index, recipient in pairs(player.GetHumans()) do
			--only include players who are not recieving a full sync
			if IsValid(recipient) and not queue_game_sync_full[recipient:EntIndex()] then table.insert(recipients, recipient) end
		end
		
		for master_index, syncs in pairs(queue_game_sync) do
			local settings = game_settings[master_index]
			
			if settings then
				send[master_index] = {}
				
				for key, value in pairs(settings) do
					if game_synced_settings[key] and syncs == true or istable(syncs) and syncs[key] then
						--we only want certain things networked
						send[master_index][key] = value
					end 
				end
			else send[master_index] = false end
		end
		
		net.Start("wire_game_core_sync")
		net.WriteTable(send)
		net.Send(recipients)
		
		queue_game_sync = {}
		queue_game_sync_check = false
	end
	
	if queue_game_sync_full_check then
		--also I'm thinking of making this compressed, but right now (11:42 PM, July 2nd 2020) I won't bother
		--wew it's been a long time, yeah no we don't need to compress this, we need to stop using write table lol ((20210214) 15:33, February 14th 2021)
		local recipients = {}
		local send = {}
		
		for recipient_index in pairs(queue_game_sync_full) do
			local recipient = Entity(recipient_index)
			
			if IsValid(recipient) then table.insert(recipients, recipient) end
		end
		
		for master_index, masters_settings in pairs(game_settings) do
			send[master_index] = {}
			
			for key, value in pairs(masters_settings) do
				if game_synced_settings[key] then
					--we only want certain things networked
					send[master_index][key] = value
				end 
			end
		end
		
		net.Start("wire_game_core_sync")
		net.WriteTable(send)
		net.Send(recipients)
		
		net.Start("wire_game_core_masters")
		net.WriteTable(game_masters)
		net.Send(recipients)
		
		queue_game_sync_full = {}
		queue_game_sync_full_check = false
	end
	
	--special cases
	if weapons_passing then
		--this means the weapon was given but the appropriate hook was not, therefore weapons_passing stayed true allowing the next weapon to be picked up even if it wasn't intended
		print("\nVVV  PLEASE REPORT THIS  VVV\n[E2 Game Core] Something interesting happened...\nThis isn't a bug but it shouldn't happen anyways, so don't freak out. If you want these traces to disappear, report them so I can patch it.")
		debug.Trace()
		print("\n^^^  PLEASE REPORT THIS  ^^^\n")
		
		weapons_passing = false
	end
	
	--down below are my recreations of the timer library!
	--because the timer library is evil, and deadly, and everything in this game is against me, and wants me dead
	--description setting delays
	for master_index, reset_time in pairs(game_describe_delay) do if cur_time > reset_time then game_describe_delay[master_index] = nil end end
	
	--for request delays, to keep players from spamming them
	for master_index, delays in pairs(game_request_delays) do
		local no_delays = true
		
		for ply_index, delay in pairs(delays) do
			if cur_time > delay then game_request_delays[master_index][ply_index] = nil
			else no_delays = false end
		end
		
		if no_delays then game_request_delays[master_index] = nil end
	end
	
	--message count and resets
	for ply_index, reset_time in pairs(game_message_resets) do
		if cur_time > reset_time then
			game_message_counts[ply_index] = nil
			game_message_resets[ply_index] = nil
		end
	end
end)

--net
net.Receive("wire_game_core_block", function(_, ply)
	local master_index = net.ReadUInt(8)
	local master_is_blocked = net.ReadBool()
	
	if master_index and master_is_blocked ~= nil then
		local ply_index = ply:EntIndex()
		
		if master_index ~= ply_index then block(ply_index, master_index, master_is_blocked) end
		
		net.Start("wire_game_core_block")
		net.WriteTable(game_blocks[ply_index] or {})
		net.Send(ply)
	end
end)

net.Receive("wire_game_core_join", function(_, ply)
	--called when they join by the browser
	local master_index = net.ReadUInt(8)
	
	if master_index then --cheaters may not send a master_index, causing script errors
		local ply_index = ply:EntIndex()
		
		if not game_masters[ply_index] and game_settings[master_index] and game_settings[master_index].open then
			local chip_index = game_constructor[master_index]
			
			if chip_index then
				local entity = Entity(chip_index)
				game_settings[master_index].requests[ply_index] = nil
				
				game_add(ply, master_index)
				
				--now run the chip that has runOnJoin
				if run_game_joins[entity] then game_function_execute(entity, {game_join_run = ply}) end
			end
		end
	end
end)

net.Receive("wire_game_core_leave", function(_, ply) if IsValid(ply) and game_masters[ply:EntIndex()] then game_remove(ply, game_constants.LEAVE_CHOICE) end end)

net.Receive("wire_game_core_request", function(_, ply)
	local response = net.ReadInt(8)
	local master_index = net.ReadUInt(8)
	
	if response and master_index then --cheaters may not send a response or master_index, causing script errors
		local chip_index = game_constructor[master_index]
		local ply_index = ply:EntIndex()
		
		if chip_index then
			if game_settings[master_index].requests[ply_index] then
				local entity = Entity(chip_index)
				
				if run_game_requests[entity] then
					game_function_execute(entity, {
						game_request_run = response,
						game_request_run_ply = ply
					})
				end
				
				if response > 0 then
					game_add(ply, master_index)
					
					--now run the chips that have runOnJoin
					if run_game_joins[entity] then game_function_execute(entity, {game_join_run = ply}) end
				elseif response == game_constants.RESPONSE_BLOCKED then block(ply_index, master_index, true) end
			end
			
			game_settings[master_index].requests[ply_index] = nil
		end
		
		--if they had other requests queued, we need to go through all of them and respond
		if net.ReadBool() then
			local queued_master_indices = net.ReadTable() or {}
			
			for index, master_index in pairs(queued_master_indices) do
				local chip_index = game_constructor[master_index]
				
				if game_constructor[master_index] then
					local entity = Entity(chip_index)
					
					game_function_execute(entity, {
						game_request_run = game_constants.RESPONSE_SUPERSEDED,
						game_request_run_ply = ply
					})
				end
			end
		end
	end
end)

net.Receive("wire_game_core_sync", function(_, ply) add_full_sync_request(ply:EntIndex()) end)

--compatibility
do
	if push_mod_hook then
		if not PushModHook_GameCore then PushModHook_GameCore = push_mod_hook end
		
		--player push mod control
		__e2setcost(2)
		e2function number gameEnablePush(enabled)
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
			
			if is_constructor then
				game_settings[master_index].defaults.push = enabled ~= 0 and true or false
				
				return 1
			end
			
			return 0
		end
		
		--detour the existing hook, to determine if the player should push the target
		--I could just do an override, but I found people modify the original push mod, like one that had convars for adjustment or another that properly calculated the view punch
		hook.Add("KeyPress", "ussy ussy ur a pussy", function(ply, key)
			if key == IN_USE then
				local eye_trace = ply:GetEyeTrace()
				local target = eye_trace.Entity
				local target_index = target:EntIndex()
				
				if IsValid(ply) and IsValid(target) and ply:IsPlayer() and target:IsPlayer() then
					local ply_index = ply:EntIndex()
					local ply_master_index = game_masters[ply_index]
					local target_index = target:EntIndex()
					local target_master_index = game_masters[target_index]
					
					if ply_master_index and target_master_index then
						--if the game lets them push and they are part of that game, let the rest happen
						if ply_master_index == target_master_index and game_settings[ply_master_index].defaults.push then push_mod_hook(ply, key) end
					elseif ply_master_index == target_master_index then push_mod_hook(ply, key) end
				end
			end
		end)
	end
	
	--ulx and its dumb enhanced respawn
	local function detour_spawn()
		hook.Add("PlayerSpawn", "UTeamSpawnAuth", function(ply)
			--prevent the stupid spawn event if they are in a game
			if not game_masters[ply:EntIndex()] then ulib_teams(ply) end
		end, HOOK_MONITOR_HIGH)
	end
	
	if not ULXUTeamSpawnAuthHook_GameCore then
		hook.Add("InitPostEntity", "wire_game_core", function()
			local hooks = hook.GetTable()
			
			if not ulib_teams then
				ulib_teams = hooks.PlayerSpawn.UTeamSpawnAuth
				ULXUTeamSpawnAuthHook_GameCore = ulib_teams
				
				if not ulib_teams then goto done end
			end
			
			detour_spawn()
			
			::done::
			
			hook.Remove("InitPostEntity", "wire_game_core")
		end)
	else detour_spawn() end
	
	--hook for ulx commands
	--hook.Call("ULibCommandCalled", _, ply, data.__cmd, argv )
end