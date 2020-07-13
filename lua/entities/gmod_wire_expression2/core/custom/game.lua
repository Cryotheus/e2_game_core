util.AddNetworkString("wire_game_core_block")
util.AddNetworkString("wire_game_core_join")
util.AddNetworkString("wire_game_core_leave")
util.AddNetworkString("wire_game_core_masters")
util.AddNetworkString("wire_game_core_request")
util.AddNetworkString("wire_game_core_sounds")
util.AddNetworkString("wire_game_core_sync")

--misc. ungrouped
--tables
local delay_game_requests = {}	--y to delay requests to certain players;		k: master index,		v: table where (k: recipient index, v: cur_time when they can send another request to the player)
local game_blocks = {}			--y for players who blocked others;				k: player index,		v: table where (k: master index, v: true)
local game_constructor = {}		--y for getting the game chip and master;		k: chip/master index,	v: master/chip index
local game_damage_dealt = {}	--y stores dealt damage multipliers;			k: player index,		v: multiplier
local game_damage_taken = {}	--y stores dealt damage multipliers;			k: player index,		v: multiplier
local game_masters = {}			--y used to fetch the player's game master;		k: player index,		v: master index
local game_settings = {}		--y stores the settings for each players game;	k: master index,		v: table where (k: setting name, v: setting value)
local ply_settings = {}			--y for restoring the player;					k: player index,		v: table where (k: state name, v: state value)

--network queue tables
local queue_game_masters = {}	--y don't remember, should probably check;
local queue_game_requests = {}	--y	stores the requests that are getting sent;	k: player index,	v: table where (k: master index, v: true)
local queue_game_sounds = {}	--y stores sounds to play on the player;		k: player index,	v: table where (k: sequential index, v: sound path)
local queue_game_sync = {}		--y stores what settings need syncing;			k: master index,	v: true
local queue_game_sync_full = {}	--y stores what players need a full sync;		k: player index,	v: true

--network queue checks
local queue_game_masters_check = false
local queue_game_requests_check = false
local queue_game_sounds_check = false
local queue_game_sync_check = false
local queue_game_sync_full_check = false

--runOn e2functions
local run_game_deaths = {}		--holds the runOnGameDeath subscriptions;			k: entity,	v: true
local run_game_joins = {}		--holds the runOnGameJoin subscriptions;			k: entity,	v: true
local run_game_leave = {}		--holds the runOnGameLeave subscriptions;			k: entity,	v: true
local run_game_requests = {}	--holds the runOnGameRequestResponse subscriptions;	k: entity,	v: true
local run_game_respawns = {}	--holds the runOnGameRespawn subscriptions;			k: entity,	v: true

--convars
local wire_game_core_sounds_max = CreateConVar("wire_game_core_sounds_max", "10", FCVAR_ARCHIVE, "How many sounds the e2 function gamePlayerPlaySound can send to a client in a single tick. This is per client. All sounds are sent in a single net message, the sound path is also truncated to 192 characters.", 0, 100)

--convars cached values
local queue_game_sounds_max = wire_game_core_sounds_max:GetInt()

----compatibility and bonus features from other addons
	local hooks = hook.GetTable()
	
	--function for pushing the player when they press use https://steamcommunity.com/sharedfiles/filedetails/?id=293535327
	local push_mod_hook = PushModHook_GameCore or hooks.KeyPress["ussy ussy ur a pussy"]
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
	RESPAWNMODE_SPECTATOR =	4, --imediately put them into spectator
	
	RESPONSE_ACCEPT =		 1, --the player accepted the request, and has become part of your game
	RESPONSE_ACCEPT_FORCED = 2, --the player has become part of your game without consent
	RESPONSE_BLOCKED =		-3, --the player blocked you from sending more requests
	RESPONSE_NONE		 =	-2, --the player didn't respond within the alotted time
	RESPONSE_DENIED =		-1, --the player denied the request
	
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
	active = false,
	block_suicide = false,
	defaults = {
		armor = 0,
		crouch_speed = 0.3,
		flashlight = false,
		gravity = 1,
		health = 100,
		ladder_speed = 200,
		max_health = 100,
		push = push_mod_hook and true or false,
		run_speed = 400,
		stroll_speed = 100,
		walk_speed = 200,
	},
	block_fall_damage = false,
	open = false,
	plys = {},
	respawn_mode = game_constants.RESPAWNMODE_INSTANT,
	title = "Unnamed Game"
}

local game_respawn_functions = {
	function(ply)
		--RESPAWN_INSTANT
		ply:Spawn()
		
		return true
	end,
	function(ply)
		--RESPAWN_DELAYED
		ply:Spawn()
		
		return true
	end,
	function(ply)
		--RESPAWN_NEVER
		
		return false
	end,
	function(ply)
		--RESPAWN_SPECTATOR
		
		return false
	end
}

local game_synced_settings = { --contains the settings that are sent to clients; k: setting name, v: true
	active = true,
	open = true,
	plys = true,
	title = true
}

--pre function setup

--local functions
local function add_full_sync_request(ply_index)
	queue_game_sync_full[ply_index] = true
	queue_game_sync_full_check = true
end

local function add_masters_sync_request(ply_index)
	queue_game_masters[ply_index] = true
	queue_game_masters_check = true
end

local function add_sound_request(ply_index, sound_path)
	table.insert(queue_game_sounds[ply_index], sound_path)
	queue_game_sounds_check = true
end

local function add_sync_request(master_index)
	queue_game_sync[master_index] = true
	queue_game_sync_check = true
end

local function block(blocker_index, blocked_index, state)
	if not state then state = nil end
	
	if game_blocks[blocker_index] then game_blocks[blocker_index][blocked_index] = state
	else game_blocks[blocker_index] = {[blocked_index] = state} end
end

local function clamp_to_floor(num, min, max) return math.floor(math.Clamp(num, min, max)) end

local function construct_game_settings(master_index)
	local master = Entity(master_index)
	local master_name = master:Nick()
	
	game_settings[master_index] = table.Copy(game_default_settings)
	game_settings[master_index].title = master_name .. (master_name[string.len(master_name)] == "s" and "' Game" or "'s Game")
end

local function game_acclimate(ply, defaults)
	ply:RemoveAllItems()
	ply:SetMaxHealth(defaults.max_health)
	ply:SetArmor(defaults.armor)
	ply:SetCrouchedWalkSpeed(defaults.crouch_speed)
	ply:SetGravity(defaults.gravity)
	ply:SetHealth(defaults.health)
	ply:SetLadderClimbSpeed(defaults.ladder_speed)
	ply:SetRunSpeed(defaults.run_speed)
	ply:SetSlowWalkSpeed(defaults.stroll_speed)
	ply:SetWalkSpeed(defaults.walk_speed)
	
	--only change it if it's different, so we don't get the click noise
	if ply:FlashlightIsOn() ~= defaults.flashlight then ply:Flashlight(defaults.flashlight) end
end

local function game_add(ply, master_index)
	local ply_index = ply:EntIndex()
	local ply_weapon = ply:GetActiveWeapon()
	local settings = game_settings[master_index]
	local settings_defaults = settings.defaults
	
	game_masters[ply_index] = master_index
	settings.plys[ply_index] = true
	
	ply_settings[ply_index] = {
		ammo = ply:GetAmmo(),
		angle = ply:EyeAngles(),
		armor = ply:Armor(),
		arsenal = {},
		crouch_speed = ply:GetCrouchedWalkSpeed(),
		--crouched = ply:Crouching(), --I don't know how to make them crouched!
		deaths = ply:Deaths(),
		flashlight = ply:FlashlightIsOn(),
		frags = ply:Frags(),
		gravity = ply:GetGravity(),
		health = ply:Health(),
		ladder_speed = ply:GetLadderClimbSpeed(),
		max_health = ply:GetMaxHealth(),
		movetype = ply:GetMoveType(),
		noclip = ply:GetMoveType() == MOVETYPE_NOCLIP,
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
	
	ply:CollisionRulesChanged()
	ply:ExitVehicle()
	ply:SetCustomCollisionCheck(true)
	ply:SetDeaths(0)
	ply:SetFrags(0)
	
	if ply_settings[ply_index].noclip then ply:SetMoveType(MOVETYPE_WALK) end
	
	--sets the player to default game settings
	game_acclimate(ply, settings_defaults)
	
	--sync!
	add_masters_sync_request(ply_index)
	add_sync_request(master_index)
	net.Start("wire_game_core_join")
	net.WriteUInt(master_index, 8)
	
	if IsValid(ply_weapon) then net.WriteString(ply_weapon:GetClass()) end
	
	net.Send(ply)
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

local function game_remove(ply, enum)
	--code for restoring players after they leave a game
	local ply_index = ply:EntIndex()
	local master_index = game_masters[ply_index]
	local settings = ply_settings[ply_index]
	
	local entity = Entity(game_constructor[master_index])
	
	--if there is no enum, don't execute the chip
	--also, we call this so early so the player can do something before the player leaves
	if enum and run_game_leave[entity] then
		entity.context.data.game_leave_run = enum
		entity.context.data.game_leave_run_ply = ply
		entity:Execute()
		entity.context.data.game_leave_run = nil
		entity.context.data.game_leave_run_ply = nil
	end
	
	add_masters_sync_request(ply_index)
	add_sync_request(master_index)
	net.Start("wire_game_core_leave")
	net.Send(ply)
	
	game_masters[ply_index] = nil
	game_settings[master_index].plys[ply_index] = nil
	
	--reset the player
	ply:RemoveAllItems()
	ply:SetSuppressPickupNotices(true)
	
	--give them back what they had
	for weapon_class, clips in pairs(settings.arsenal) do
		local weapon = ply:Give(weapon_class, true)
		
		weapon:SetClip1(clips[1])
		weapon:SetClip2(clips[2])
	end
	
	for ammo_type, ammo_count in pairs(settings.ammo) do ply:GiveAmmo(ammo_count, ammo_type, true) end
	
	ply:CollisionRulesChanged()
	ply:ExitVehicle()
	ply:SetArmor(settings.armor)
	ply:SetCrouchedWalkSpeed(settings.crouch_speed)
	ply:SetCustomCollisionCheck(false)
	ply:SetDeaths(settings.deaths)
	ply:SetEyeAngles(settings.angle)
	ply:SetFrags(settings.frags)
	ply:SetGravity(settings.gravity)
	ply:SetHealth(settings.health)
	ply:SetLadderClimbSpeed(settings.ladder_speed)
	ply:SetMaxHealth(settings.max_health)
	ply:SetMoveType(settings.movetype)
	ply:SetPos(settings.position)
	ply:SetRunSpeed(settings.run_speed)
	ply:SetSlowWalkSpeed(settings.stroll_speed)
	ply:SetSuppressPickupNotices(false)
	ply:SetVelocity(settings.velocity)
	ply:SetWalkSpeed(settings.walk_speed)
	
	--only change it if it's different, so we don't get the click noise
	if ply:FlashlightIsOn() ~= settings.flashlight then ply:Flashlight(settings.flashlight) end
	
	--remove the settings
	ply_settings[ply_index] = nil
end

local function game_remove_all(master_index, forced)
	local chip_index = game_constructor[master_index]
	local enum
	
	if not forced then enum = game_constants.LEAVE_REMOVED end
	
	for ply_index, current_master_index in pairs(game_masters) do
		if current_master_index == master_index then
			local ply = Entity(ply_index)
			
			if IsValid(ply) then game_remove(ply, enum) end
		end
	end
end

local function game_set_closed(master_index, forced)
	game_remove_all(master_index, forced)
	
	game_constructor[game_constructor[master_index]] = nil
	game_constructor[master_index] = nil
	game_settings[master_index] = nil
end

local function give_weapon(ply, weapon_class, supress_ammo)
	if not ply:Alive() then return NULL end
	
	local swep = list.Get("Weapon")[weapon_class]
	
	if not swep then return end
	if (swep.AdminOnly or not swep.Spawnable) and not ply:IsAdmin() then return NULL end
	
	local swep_class = swep.ClassName
	
	if not ply:HasWeapon(swep_class) then return ply:Give(swep_class, supress_ammo) end
	
	return NULL
end

--post function setup
E2Lib.RegisterExtension("game", true,
	"Allows players to have more control over other players, as long as the other player consents. Players will be restored to their original state (including position), upon leaving a game.",
	"Oh god oh shit.")

for enum, value in pairs(game_constants) do E2Lib.registerConstant("_GAME" .. enum, value) end

--e2functions
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
	
	--why does game settings not always exist when I reach this function? It should as construct is called when the e2 is loaded
	if not game_settings[master_index] then
		print("Looks like game_settings was not constructed when we opened the game... here's the trace:")
		debug.Trace()
		print("Constructing...")
		
		construct_game_settings(master_index)
	end
	
	game_constructor[chip_index] = master_index
	game_constructor[master_index] = chip_index
	game_settings[master_index].active = true
	
	add_sync_request(master_index)
	
	return 1
end

----player e2functions
do
	__e2setcost(5)
	e2function number gamePlayerCount()
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then return table.Count(game_settings[master_index].plys) end
		
		return -1
	end
	
	__e2setcost(6)
	e2function number entity:gamePlayerCount()
		if IsValid(this) and this.context then
			local is_constructor, chip_index, master_index = game_evaluator_constructor_only(this.context)
			
			return table.Count(game_settings[master_index].plys)
		end
		
		return -1
	end
	
	__e2setcost(4)
	e2function number entity:gamePlayerGiveAmmo(string ammo_type, amount)
		local is_participating = game_evaluator_player_only(self, this)
		
		if is_participating then
			this:GiveAmmo(amount, ammo_type, true)
			
			return 1
		end
		
		return 0
	end
	
	e2function number entity:gamePlayerGiveAmmo(string ammo_type, amount, show_pop_up)
		local is_participating = game_evaluator_player_only(self, this)
		
		if is_participating then
			this:GiveAmmo(amount, ammo_type, show_pop_up == 0)
			
			return 1
		end
		
		return 0
	end
	
	__e2setcost(10)
	e2function entity entity:gamePlayerGiveWeapon(string weapon_class)
		local is_participating = game_evaluator_player_only(self, this)
		
		if is_participating then return give_weapon(this, weapon_class, true) end
		
		return NULL
	end
	
	e2function entity entity:gamePlayerGiveWeapon(string weapon_class, fill_clip)
		local is_participating = game_evaluator_player_only(self, this)
		
		if is_participating then return give_weapon(this, weapon_class, fill_clip == 0) end
		
		return NULL
	end
	
	e2function number gamePlayerRemove()
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_remove_all(this)
			
			return 1
		end
		
		return 0
	end
	
	e2function number entity:gamePlayerRemove()
		local is_participating, ply_index, chip_index, master_index = game_evaluator_player_only(self, this)
		
		if is_participating then
			game_remove(this, game_constants.LEAVE_REMOVED)
			
			return 1
		end
		
		return 0
	end
	
	__e2setcost(20)
	e2function number gamePlayerRespawn()
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			timer.Simple(0, function() for ply_index in pairs(game_settings[master_index].plys) do Entity(ply_index):Spawn() end end)
			
			return 1
		end
		
		return 0
	end
	
	__e2setcost(8)
	e2function number entity:gamePlayerRespawn()
		local is_participating = game_evaluator_player_only(self, this)
		
		if is_participating then
			timer.Simple(0, function() this:Spawn() end)
			
			return 1
		end
		
		return 0
	end
	
	__e2setcost(20)
	e2function number gamePlayerPlaySound(string sound_path)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			local sound_path_truncated = string.sub(sound_path, 1, 192)
			
			--keep the exploiters away
			if string.match(sound_path_truncated, '["?]') then return 0 end
			
			for ply_index in pairs(game_settings[master_index].plys) do
				if not queue_game_sounds[ply_index] then queue_game_sounds[ply_index] = {} end
				if #queue_game_sounds[ply_index] < queue_game_sounds_max then
					queue_game_sounds_check = true
					
					table.insert(queue_game_sounds[ply_index], sound_path_truncated)
				end
			end
			
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
	
	__e2setcost(4)
	e2function number entity:gamePlayerSetClip1(amount)
		if IsValid(this) and this:IsWeapon() then
			owner = this:GetOwner()
			
			if IsValid(owner) then
				local is_participating, ply_index, chip_index, master_index = game_evaluator_player_only(self, owner)
				
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
	
	e2function number entity:gamePlayerSetClip2(amount)
		if IsValid(this) and this:IsWeapon() then
			owner = this:GetOwner()
			
			if IsValid(owner) then
				local is_participating, ply_index, chip_index, master_index = game_evaluator_player_only(self, owner)
				
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
	
	__e2setcost(3)
	e2function number entity:gamePlayerSetDamageDealtMultiplier(multiplier)
		local is_participating, ply_index, chip_index, master_index = game_evaluator_player_only(self, this)
		
		if is_participating then
			if multiplier == 1 then game_damage_dealt[ply_index] = nil
			else game_damage_dealt[ply_index] = math.Clamp(multiplier, 0, 1000) end
			
			return 1
		end
		
		return 0
	end
	
	e2function number entity:gamePlayerSetDamageTakenMultiplier(multiplier)
		local is_participating, ply_index, chip_index, master_index = game_evaluator_player_only(self, this)
		
		if is_participating then
			if multiplier == 1 then game_damage_dealt[ply_index] = nil
			else game_damage_taken[ply_index] = math.Clamp(multiplier, 0, 1000) end
			
			return 1
		end
		
		return 0
	end
	
	__e2setcost(10)
	e2function number gamePlayerStripAmmo()
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			for ply_index in pairs(game_settings[master_index].plys) do Entity(ply_index):StripAmmo() end
			
			return 1
		end
		
		return 0
	end
	
	__e2setcost(4)
	e2function number entity:gamePlayerStripAmmo()
		local is_participating = game_evaluator_player_only(self, this)
		
		if is_participating then
			this:StripAmmo()
			
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
				
				ply:StripAmmo()
				ply:StripWeapons()
			end
			
			return 1
		end
		
		return 0
	end
	
	__e2setcost(10)
	e2function number entity:gamePlayerStripEverything()
		local is_participating = game_evaluator_player_only(self, this)
		
		if is_participating then
			this:StripAmmo()
			this:StripWeapons()
			
			return 1
		end
		
		return 0
	end
	
	__e2setcost(15)
	e2function number gamePlayerStripWeapon()
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			for ply_index in pairs(game_settings[master_index].plys) do Entity(ply_index):StripWeapons() end
			
			return 1
		end
		
		return 0
	end
	
	__e2setcost(7)
	e2function number gamePlayerStripWeapon(string weapon_class)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			for ply_index in pairs(game_settings[master_index].plys) do Entity(ply_index):StripWeapon(weapon_class) end
			
			return 1
		end
		
		return 0
	end
	
	__e2setcost(6)
	e2function number entity:gamePlayerStripWeapon()
		local is_participating = game_evaluator_player_only(self, this)
		
		if is_participating then
			this:StripWeapons()
			
			return 1
		end
		
		return 0
	end
	
	__e2setcost(3)
	e2function number entity:gamePlayerStripWeapon(string weapon_class)
		local is_participating = game_evaluator_player_only(self, this)
		
		if is_participating then
			this:StripWeapon(weapon_class)
			
			return 1
		end
		
		return 0
	end
end

--back to misc.
__e2setcost(8)
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
		if delay_game_requests[master_index] and delay_game_requests[master_index][ply_index] then return game_constants.REQUEST_LIMITED end
		
		--if they're a bot, and the master is an admin, force the bot into the game
		if this:IsBot() and master:IsAdmin() then game_add(this, master_index) end
		
		--we made it, now time to send the request
		if queue_game_requests[ply_index] then queue_game_requests[ply_index][master_index] = true
		else
			queue_game_requests[ply_index] = {[master_index] = true}
			queue_game_requests_check = true
		end
		
		--then make the delay
		--if the owner makes the request we will just put them into the game and return game_constants.RESPONSE_ACCEPT_FORCED
		if delay_game_requests[master_index] then delay_game_requests[master_index][ply_index] = CurTime() + 5
		else delay_game_requests[master_index] = {[ply_index] = CurTime() + 5} end
		
		return game_constants.REQUEST_SENT
		
	else return game_constants.REQUEST_INVALID_TARGET end
	
	return game_constants.REQUEST_UNKNOWN
end

----default game settings e2functions
do
	__e2setcost(2)
	e2function number gameSetDefaultArmor(armor)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.armor = clamp_to_floor(armor, 0, 1000)
			
			return 1
		end
		
		return 0
	end

	e2function number gameSetDefaultCrouchSpeedMultiplier(multiplier)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.crouch_speed = clamp_to_floor(multiplier, 0, 10)
			
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
		local is_constructor = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.gravity = clamp_to_floor(multiplier, -10, 10)
			
			return 1
		end
		
		return 0
	end

	e2function number gameSetDefaultHealth(health)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.health = clamp_to_floor(health, 1, 1000)
			
			return 1
		end
		
		return 0
	end

	e2function number gameSetDefaultLadderSpeed(speed)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.ladder_speed = clamp_to_floor(speed, 0, 2000)
			
			return 1
		end
		
		return 0
	end

	e2function number gameSetDefaultMaxHealth(max)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.max_health = clamp_to_floor(max, 1, 1000)
			
			return 1
		end
		
		return 0
	end

	e2function number gameSetDefaultRunSpeed(speed)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.run_speed = clamp_to_floor(speed, 0, 1000)
			
			return 1
		end
		
		return 0
	end

	e2function number gameSetDefaultSpeed(speed)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.walk_speed = clamp_to_floor(speed, 0, 1000)
			
			return 1
		end
		
		return 0
	end

	e2function number gameSetDefaultWalkSpeed(speed)
		local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
		
		if is_constructor then
			game_settings[master_index].defaults.stroll_speed = clamp_to_floor(speed, 0, 1000)
			
			return 1
		end
		
		return 0
	end
end

--back to misc.
__e2setcost(3)
e2function number gameSetJoinable(joinable)
	local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
	
	if is_constructor then
		add_sync_request(master_index)
		
		game_settings[master_index].open = joinable ~= 0 and true or false
		
		return 1
	end
	
	return 0
end

__e2setcost(1)
e2function number gameSetRespawnMode(enum)
	local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
	
	if is_constructor then
		game_settings[master_index].respawn_mode = enum > 0 and enum < 5 and enum or 1
		
		return 1
	end
	
	return 0
end

__e2setcost(3)
e2function number gameSetTitle(string title)
	local is_constructor, chip_index, master_index = game_evaluator_constructor_only(self)
	
	if is_constructor then
		add_sync_request(master_index)
		
		game_settings[master_index].title = string.sub(title, 1, 64)
		
		return 1
	end
	
	return 0
end

----run functions
do
	----runOnGame*(activate)
	do
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
	
	----game*Clk()
	do
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
	
	----game**()
	do
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
		print("game core construct", self, self.entity)
		
		local master_index = self.player:EntIndex()
		
		if master_index and not game_settings[master_index] then construct_game_settings(master_index) end
	end
)

registerCallback("destruct",
	function(self)
		local entity = self.entity
		local master_index = game_constructor[entity:EntIndex()]
		
		print("game core destruct", self, entity)
		
		run_game_deaths[entity] = nil
		run_game_joins[entity] = nil
		run_game_leave[entity] = nil
		run_game_requests[entity] = nil
		run_game_respawns[entity] = nil
		
		if master_index then game_set_closed(master_index, true) end
	end
)

--hooks
hook.Add("CanPlayerEnterVehicle", "wire_game_core", function(ply, vehicle)
	local master_index = game_masters[ply:EntIndex()]
	
	if master_index then
		local context = Entity(game_constructor[master_index]).context
		
		return E2Lib.getOwner(context, vehicle) == Entity(master_index)
	end
end)

hook.Add("CanPlayerSuicide", "wire_game_core", function(ply)
	local master_index = game_masters[ply:EntIndex()]
	
	if master_index and game_settings[master_index].block_suicide then return false end
end)

hook.Add("EntityTakeDamage", "wire_game_core", function(victim, damage_info)
	local attacker = damage_info:GetAttacker()
	local attacker_index = attacker:EntIndex()
	local attacker_valid = IsValid(attacker)
	local victim_index = victim:EntIndex()
	local master_index = game_masters[victim_index]
	
	--keep players safe from outside sources
	if attacker_valid and attacker:IsPlayer() and master_index ~= game_masters[attacker_index] then print("no minge") return true end
	
	if master_index then
		local settings = game_settings[master_index]
		
		--might as well do this here because we are using a damage hook already
		if damage_info:IsFallDamage() and settings.block_fall_damage then return true end
		if game_damage_taken[victim_index] then damage_info:ScaleDamage(game_damage_taken[victim_index]) end
		
		if attacker_valid and game_damage_dealt[attacker_index] then damage_info:ScaleDamage(game_damage_dealt[attacker_index]) end
	end
end)

hook.Add("PlayerDeath", "wire_game_core", function(victim, inflictor, attacker)
	local master_index = game_masters[victim:EntIndex()]
	
	if master_index then
		local entity = Entity(game_constructor[master_index])
		
		if run_game_deaths[entity] then
			entity.context.data.game_death_run = victim
			entity.context.data.game_death_run_attacker = attacker
			entity.context.data.game_death_run_inflictor = inflictor
			entity:Execute()
			entity.context.data.game_death_run = nil
			entity.context.data.game_death_run_attacker = nil
			entity.context.data.game_death_run_inflictor = nil
		end
	end
end)

hook.Add("PlayerDeathThink", "wire_game_core", function(ply)
	local master_index = game_masters[ply:EntIndex()]
	
	if master_index then game_respawn_functions[game_settings[master_index].respawn_mode](ply, master_index) end
end)

hook.Add("PlayerDisconnected", "wire_game_core", function(ply)
	--supposedly reliable now?
	local ply_index = ply:EntIndex()
	
	if game_constructor[ply_index] then game_set_closed(ply_index, true)
	elseif game_masters[ply_index] then game_remove(ply, game_constants.LEAVE_DISCONNECT) end
end)

hook.Add("PlayerInitialSpawn", "wire_game_core", function(ply)
	--PlayerDisconnected is not reliable, this hook is (except for networking stuff, which is why we wait for the client's InitPostEntity hook to run before we sync)
	local ply_index = ply:EntIndex()
	
	delay_game_requests[ply_index] = nil
	game_blocks[ply_index] = nil
	game_masters[ply_index] = nil
	game_settings[ply_index] = nil
	ply_settings[ply_index] = nil
end)

hook.Add("PlayerNoClip", "wire_game_core", function(ply, desire) if game_masters[ply:EntIndex()] and desire then return false end end)

hook.Add("PlayerSpawn", "wire_game_core", function(ply)
	local ply_index = ply:EntIndex()
	local master_index = game_masters[ply_index]
	
	if master_index then
		local entity = Entity(game_constructor[master_index])
		
		game_acclimate(ply, game_settings[master_index].defaults)
		
		if run_game_respawns[entity] then
			entity.context.data.game_respawn_run = ply
			entity:Execute()
			entity.context.data.game_respawn_run = ply
		end
		
		if ulib_spawn then ply.ULibSpawnInfo = nil end
		
		return true
	end
end)

hook.Add("PlayerSpawnObject", "wire_game_core", function(ply) if game_masters[ply:EntIndex()] then return false end end)

hook.Add("ShouldCollide", "wire_game_core", function(ent_1, ent_2)
	if ent_1:IsPlayer() and ent_2:IsPlayer() and game_masters[ent_1:EntIndex()] ~= game_masters[ent_2:EntIndex()] then return false end
	
	return true
end)

hook.Add("Think", "wire_game_core", function()
	--I need a better queuing system
	local cur_time = CurTime()
	
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
		
		for master_index in pairs(queue_game_sync) do
			send[master_index] = {}
			
			for key, value in pairs(game_settings[master_index] or {}) do
				if game_synced_settings[key] then
					--we only want certain things networked
					send[master_index][key] = value
				end 
			end
		end
		
		net.Start("wire_game_core_sync")
		net.WriteTable(send)
		net.Send(recipients)
		
		queue_game_sync = {}
		queue_game_sync_check = false
	end
	
	if queue_game_sync_full_check then
		--also I'm thinking of making this compressed, but right now (11:42 PM, July 2nd 2020) I won't bother
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
	
	for master_index, delays in pairs(delay_game_requests) do
		local no_delays = true
		
		for ply_index, delay in pairs(delays) do
			if cur_time > delay then delay_game_requests[master_index][ply_index] = nil
			else no_delays = false end
		end
		
		if no_delays then delay_game_requests[master_index] = nil end
	end
end)

--net
net.Receive("wire_game_core_block", function(_, ply)
	local master_index = net.ReadUInt(8)
	local master_is_blocked = net.ReadBool()
	local ply_index = ply:EntIndex()
	
	block(ply_index, master_index, master_is_blocked)
	
	net.Start("wire_game_core_block")
	net.WriteTable(game_blocks[ply_index] or {})
	net.Send(ply)
end)

net.Receive("wire_game_core_leave", function(_, ply) if IsValid(ply) and game_masters[ply:EntIndex()] then game_remove(ply, game_constants.LEAVE_CHOICE) end end)

net.Receive("wire_game_core_request", function(_, ply)
	local ply_index = ply:EntIndex()
	local response = net.ReadInt(8)
	local master_index = net.ReadUInt(8)
	
	if game_constructor[master_index] then
		local entity = Entity(game_constructor[master_index])
		
		if run_game_requests[entity] then
			entity.context.data.game_request_run = response
			entity.context.data.game_request_run_ply = ply
			entity:Execute()
			entity.context.data.game_request_run = nil
			entity.context.data.game_request_run_ply = nil
		end
		
		if response > 0 then
			game_add(ply, master_index)
			
			--now run those who have runOnJoin
			if run_game_joins[entity] then
				entity.context.data.game_join_run = ply
				entity:Execute()
				entity.context.data.game_join_run = nil
			end
		elseif response == game_constants.RESPONSE_BLOCKED then block(ply_index, master_index, true) end
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
			end
			
			detour_spawn()
			
			hook.Remove("InitPostEntity", "wire_game_core")
		end)
	else detour_spawn() end
end