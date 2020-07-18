--I am a faithful believer of DRY (Don't Repeat Yourself!)
--that's why we create this prefix system
local function_descriptions = {
	["gameClose"] =								{2, "Closes the game, restoring all players. Returns 1 upon success, 0 upon failure."},
	["gameDeathAttacker"] =						{5, 'Returns the entity that killed the victim if the current execution was caused by "runOnGameDeath".'},
	["gameDeathClk"] =							{5, 'Returns the player that died if the current execution was caused by "runOnGameDeath".'},
	["gameDeathInflictor"] =					{5, 'Returns the entity that inflicted damage on the victim if the current execution was caused by "runOnGameDeath".'},
	["gameEnableFallDamage"] =					{3, "Enables or disables fall damage for all players in the game."},
	["gameEnablePush"] =						{3, "Enables or disables the ability for players to push others, requires Jordie's push mod, or compatible. > https://steamcommunity.com/sharedfiles/filedetails/?id=293535327"},
	["gameEnableSuicide"] =						{3, "Enables or disables suicide for all players in the game."},
	["gameJoinClk"] =							{6, 'Returns the player that joined the game if the current execution was caused by "runOnGameJoin".'},
	["gameLeaveClk"] =							{5, 'Returns a GAMELEAVE enum if the current execution was caused by "runOnGameLeave".'},
	["gameLeavePlayer"] =						{5, 'Returns the player that left the game if the current execution was caused by "runOnGameLeave".'},
	["gameOpen"] =								{1, "Opens a game using the chip which runs it. You can only have one game open at a time! Only the chip that opened the game can use the game functions for the active game. If you wish to open a game on another chip, you must use gameClose to do so."},
	["gamePlayerCount"] =						{3, "Returns the amount of players in the chip's game. Returns -1 on fail."},
	["gamePlayerCount(e:)"] =					{0, "Returns the amount of players in the chip's game. Returns -1 on fail."},
	["gamePlayerGiveAmmo(e:sn)"] =				{5, "Gives the player the specified amount (parameter #2) of ammo by its ammo type (parameter #1). Will return 1 on success."},
	["gamePlayerGiveAmmo(e:snn)"] =				{5, "Gives the player the specified amount (parameter #2) of ammo by its ammo type (parameter #1), and will show a HUD pop up if show_pop_up (parameter #3) is non-zero. Will return 1 on success."},
	["gamePlayerGiveWeapon(e:s)"] =				{5, 'Gives the player the weapon by the class name, the weapon will not have ammo in reserve or clip. Will return the weapon on success, and "noentity" on fail.'},
	["gamePlayerGiveWeapon(e:sn)"] =			{5, 'Gives the player the weapon by the class name, the weapon will not have ammo in reserve, and will only have some ammo (inconsistent) if give_ammo is non-zero. Will return the weapon on success, and "noentity" on fail.'},
	["gamePlayerPlaySound(s)"] =				{3, "Plays the specified sound on all players in the game. Volume, pitch, duration, etc. cannot be adjusted as the freedom to do so is not provided by the internal function. Returns 1 on success, the operation will be considered successful even if no players hear the sound."},
	["gamePlayerPlaySound(e:s)"] =				{5, "Plays the specified sound on the player. Volume, pitch, duration, etc. cannot be adjusted as the freedom to do so is not provided by the internal function. Returns 1 on success."},
	["gamePlayerRemove(e:)"] =					{5, "Removes the player from the game, restoring them to their original state."},
	["gamePlayerRemove"] =						{3, "Removes all players from the game, restoring them to their original states."},
	["gamePlayerRespawn"] =						{3, "Respawns all players."},
	["gamePlayerRespawn(e:)"] =					{5, "Respawns the specified player."},
	["gamePlayerSetAng"] =						{5, "Sets the player's eye angles."},
	["gamePlayerSetClip1(e:n)"] =				{5, 'Sets the amount of ammo in the weapon\'s clip, this is a macro for "entity:gamePlayerSetClip1(string, number)".'}, --only reason I don't use [[ description ]] is because they gross me out
	["gamePlayerSetClip1(e:sn)"] =				{5, "Sets the amount of ammo in the weapon's clip, given the class name."},
	["gamePlayerSetClip2(e:n)"] =				{5, 'Sets the amount of ammo in the weapon\'s secondary clip, this is a macro for "entity:gamePlayerSetClip2(string, number)".'}, --only reason I don't use [[ description ]] is because they gross me out
	["gamePlayerSetClip2(e:sn)"] =				{5, "Sets the amount of ammo in the weapon's secondary clip, given the class name."},
	["gamePlayerSetDamageDealtMultiplier"] =	{5, "Sets the player's damage dealt multiplier."},
	["gamePlayerSetDamageDealtMultiplier"] =	{3, "Sets all players' damage dealt multiplier."},
	["gamePlayerSetDamageTakenMultiplier"] =	{5, "Sets the player's damage taken multiplier."},
	["gamePlayerSetDamageTakenMultiplier"] =	{3, "Sets all players' damage taken multiplier."},
	["gamePlayerSetPos"] =						{5, "Sets the player's position."},
	["gamePlayerStripAmmo"] =					{3, "Strips all the ammo from all players."},
	["gamePlayerStripAmmo(e:)"] =				{5, "Strips all the ammo from the specified player."},
	["gamePlayerStripEverything"] =				{3, "Strips all the ammo and weapons from all players."},
	["gamePlayerStripEverything(e:)"] =			{5, "Strips all the ammo and weapons the specified player."},
	["gamePlayerStripWeapon"] =					{3, "Strips all weapons from all players in the chip's game."},
	["gamePlayerStripWeapon(e:)"] =				{5, "Strips all weapons from the specified player."},
	["gamePlayerStripWeapon(s)"] =				{3, "Strips the weapon by its class name from all players."},
	["gamePlayerStripWeapon(e:s)"] =			{5, "Strips the weapon by its class name from the specified player."},
	["gameRequest"] =							{4, "Sends a request for the player to join your game. Returns a GAMEREQUEST enum. Do note there is a delay between sending requests on the same player."},
	["gameRequestResponseClk"] =				{6, 'Returns a GAMERESPONSE enum if the current execution was caused by "runOnGameRequestResponse".'},
	["gameRequestResponsePlayer"] =				{6, 'Returns the player that responded to the game request if the current execution was caused by "runOnGameRequestResponse".'},
	["gameRespawnClk"] =						{6, 'Returns the player that respawned if the current execution was caused by "runOnGameRespawn".'},
	["gameSetDefaultArmor"] =					{3, "Sets the default armor that joining players or respawning players will spawn with."},
	["gameSetDefaultCrouchSpeedMultiplier"] =	{3, "Sets the default crouch speed multiplier that joining players or respawning players will spawn with."},
	["gameSetDefaultFlashlight"] =				{3, "Sets the state that joining players or respawning players will have their flashlight set to."},
	["gameSetDefaultGravity"] =					{-3, "Sets the gravity multiplier that joining players or respawning players will spawn with.", "Gravity is not synced between the server and client as the SetGravity method is not predicted. With high amounts of latency, players may notice some jittering. Check the issue trakcer, #3648."},
	["gameSetDefaultHealth"] =					{3, "Sets the health that joining players or respawning players will spawn with."},
	["gameSetDefaultLadderSpeed"] =				{3, "Sets the ladder climbing speed that joining players or respawning players will spawn with."},
	["gameSetDefaultMaxHealth"] =				{3, "Sets the maximum health that joining players or respawning players will spawn with."},
	["gameSetDefaultRunSpeed"] =				{3, "Sets the run speed that joining players or respawning players will spawn with."},
	["gameSetDefaultSpeed"] =					{3, "Sets the movement speed that joining players or respawning players will spawn with."},
	["gameSetDefaultWalkSpeed"] =				{3, "Sets the walk speed that joining players or respawning players will spawn with."},
	["gameSetJoinable"] =						{3, 'Allows players to join the game from the game browser, without needing an invite from "gameRequest".'},
	["gameSetRespawnMode"] =					{3, "Sets the respawn mode using a RESPAWNMODE enum."},
	["gameSetTitle"] =							{3, "Sets the game's title that joining and browsing players will see."},
	["runOnGameDeath"] =						{0, "If set to 1, the expression will execute when a player that is part of your chip's game dies."},
	["runOnGameJoin"] =							{0, "If set to 1, the expression will execute when a player joins the game created by your chip."},
	["runOnGameLeave"] =						{0, "If set to 1, the expression will execute when a player leaves the game created by your chip."},
	["runOnGameRequestResponse"] =				{0, "If set to 1, the expression will execute upon receiving a game request response."},
	["runOnGameRespawn"] =						{0, "IF set to 1, the expression will execute when a player that is part of your chip's game is respawned."}
}

local function_description_prefixes = {
	"Only functions when you have not started a game.\n", --1
	"Only functions when you have started a game.\n", --2
	"Only functions when the chip has started a game.\n", --3
	"Only functions when the chip has started a game, and the target player has not blocked you.\n", --4
	"Only functions when the chip has started a game, and the target player is part of the game.\n", --5
	"Only functions when the chip had previously started a game.\n", --6
	[0] = ""
}

for name, data in pairs(function_descriptions) do
	local prefix_type = data[1]
	
	if prefix_type < 0 then
		local wip_prefix = data[3]
		
		if wip_prefix then E2Helper.Descriptions[name] = "[WORK IN PROGRESS: " .. wip_prefix .. "] " .. function_description_prefixes[math.abs(prefix_type)] .. data[2]
		else E2Helper.Descriptions[name] = "[WORK IN PROGRESS] " .. function_description_prefixes[math.abs(prefix_type)] .. data[2] end
	else E2Helper.Descriptions[name] = function_description_prefixes[prefix_type] .. data[2] end
end

--clean up!
function_descriptions = nil