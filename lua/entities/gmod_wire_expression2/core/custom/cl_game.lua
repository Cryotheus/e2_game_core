--I am a faithful believer of DRY (Don't Repeat Yourself!)
--that's why we create a prefix system
local function_descriptions = {
	["gameCameraAng"] =								3,
	["gameCameraCreate(n)"] =						3,
	["gameCameraCreate(nv)"] =						3,
	["gameCameraCreate(nva)"] =						3,
	["gameCameraEntity"] =							3,
	["gameCameraFOV"] =								3,
	["gameCameraLerp(nnv)"] =						3,
	["gameCameraLerp(nnvv)"] =						3,
	["gameCameraLerpBezier"] =						3,
	["gameCameraParent(ne)"] =						3,
	["gameCameraPos"] =								3,
	["gameCameraRemove"] =							3,
	["gameCameraRemoveAll"] =						3,
	["gameCameraUnparent"] =						3,
	["gameClose"] =									2,
	["gameDeathAttacker"] =							5,
	["gameDeathClk"] =								5,
	["gameDeathInflictor"] =						5,
	["gameDescriptionDelay"] =						0,
	["gameEnableFallDamage"] =						3,
	["gameEnablePlayerCollision"] =					3,
	["gameEnablePush"] =							3,
	["gameEnableSuicide"] =							3,
	["gameJoinClk"] =								6,
	["gameLeaveClk"] =								5,
	["gameLeavePlayer"] =							5,
	["gameMessageCanSend"] =						5,
	["gameMessageMax"] =							0,
	["gameMessageMaxComponents"] =					0,
	["gameMessageMaxLength"] =						0,
	["gameOpen"] =									1,
	["gamePlayerAcclimate"] =						3,
	["gamePlayerAcclimate(e.)"] =					5,
	["gamePlayerAddDeaths"] =						3,
	["gamePlayerAddDeaths(e:n)"] =					5,
	["gamePlayerAddFrags"] =						3,
	["gamePlayerAddFrags(e:n)"] =					5,
	["gamePlayerApplyForce"] =						5,
	["gamePlayerCollidableSet"] =					{-7, true},
	["gamePlayerCount"] =							3,
	["gamePlayerCount(e:)"] =						0,
	["gamePlayerGiveAmmo(sn)"] =					3,
	["gamePlayerGiveAmmo(snn)"] =					3,
	["gamePlayerGiveAmmo(e:sn)"] =					5,
	["gamePlayerGiveAmmo(e:snn)"] =					5,
	["gamePlayerGiveWeapon(s)"] =					3,
	["gamePlayerGiveWeapon(e:s)"] =					5,
	["gamePlayerGiveWeapon(sn)"] =					3,
	["gamePlayerGiveWeapon(e:sn)"] =				5,
	["gamePlayerKill"] =							3,
	["gamePlayerKill(e:)"] =						5,
	["gamePlayerMessage"] =							3,
	["gamePlayerMessage(e.n...)"] =					5,
	["gamePlayerMessage(e.nn...)"] =				5,
	["gamePlayerMessageClear"] =					3,
	["gamePlayerMessageClear(e:)"] =				5,
	["gamePlayerPlaySound(s)"] =					3,
	["gamePlayerPlaySound(e:s)"] =					5,
	["gamePlayerRemove(e:)"] =						5,
	["gamePlayerRemove"] =							3,
	["gamePlayerRespawn"] =							3,
	["gamePlayerRespawn(e:)"] =						5,
	["gamePlayers"] =								3,
	["gamePlayersAlive"] =							3,
	["gamePlayersDead"] =							3,
	["gamePlayerSetAng"] =							5,
	["gamePlayerSetArmor"] =						3,
	["gamePlayerSetArmor(e:n)"] =					5,
	["gamePlayerSetCamera(e:)"] =					5,
	["gamePlayerSetCamera(e:n)"] =					5,
	["gamePlayerSetClip1(e:n)"] =					5,
	["gamePlayerSetClip1(e:sn)"] =					5,
	["gamePlayerSetClip1(sn)"] =					3,
	["gamePlayerSetClip2(e:n)"] =					5,
	["gamePlayerSetClip2(e:sn)"] =					5,
	["gamePlayerSetClip2(sn)"] =					3,
	["gamePlayerSetCrouchSpeedMultiplier"] =		3,
	["gamePlayerSetCrouchSpeedMultiplier(e:n)"] =	5,
	["gamePlayerSetDamageDealtMultiplier"] =		3,
	["gamePlayerSetDamageDealtMultiplier(e:n)"] =	5,
	["gamePlayerSetDamageTakenMultiplier"] =		5,
	["gamePlayerSetDamageTakenMultiplier(e:n)"] =	3,
	["gamePlayerSetDeaths"] =						3,
	["gamePlayerSetDeaths(e:n)"] =					5,
	["gamePlayerSetFrags"] =						3,
	["gamePlayerSetFrags(e:n)"] =					5,
	["gamePlayerSetHealth"] =						3,
	["gamePlayerSetHealth(e:n)"] =					5,
	["gamePlayerSetJumpPower"] =					3,
	["gamePlayerSetJumpPower(e:n)"] =				5,
	["gamePlayerSetLadderSpeed"] =					3,
	["gamePlayerSetLadderSpeed(e:n)"] =				5,
	["gamePlayerSetMaxArmor"] =						3,
	["gamePlayerSetMaxArmor(e:n)"] =				5,
	["gamePlayerSetMaxHealth"] =					3,
	["gamePlayerSetMaxHealth(e:n)"] =				5,
	["gamePlayerSetPos"] =							5,
	["gamePlayerSetRunSpeed"] =						3,
	["gamePlayerSetRunSpeed(e:n)"] =				5,
	["gamePlayerSetSpeed"] =						3,
	["gamePlayerSetSpeed(e:n)"] =					5,
	["gamePlayerSetWalkSpeed"] =					3,
	["gamePlayerSetWalkSpeed(e:n)"] =				5,
	["gamePlayerStripAmmo"] =						3,
	["gamePlayerStripAmmo(e:)"] =					5,
	["gamePlayerStripEverything"] =					3,
	["gamePlayerStripEverything(e:)"] =				5,
	["gamePlayerStripWeapon"] =						3,
	["gamePlayerStripWeapon(e:)"] =					5,
	["gamePlayerStripWeapon(s)"] =					3,
	["gamePlayerStripWeapon(e:s)"] =				5,
	["gameRequest"] =								4,
	["gameRequestResponseClk"] =					6,
	["gameRequestResponsePlayer"] =					6,
	["gameRespawnClk"] =							6,
	["gameSetDefaultArmor"] =						3,
	["gameSetDefaultCrouchSpeedMultiplier"] =		3,
	["gameSetDefaultDamageDealtMultiplier"] =		3,
	["gameSetDefaultDamageTakenMultiplier"] =		3,
	["gameSetDefaultFlashlight"] =					3,
	["gameSetDefaultGravity"] =						{-3, true}, 
	["gameSetDefaultHealth"] =						3,
	["gameSetDefaultJumpPower"] =					3,
	["gameSetDefaultLadderSpeed"] =					3,
	["gameSetDefaultMaxArmor"] =					3,
	["gameSetDefaultMaxHealth"] =					3,
	["gameSetDefaultRespawnDelay"] =				3,
	["gameSetDefaultRespawnMode"] =					3,
	["gameSetDefaultRunSpeed"] =					3,
	["gameSetDefaultSpeed"] =						3,
	["gameSetDefaultWalkSpeed"] =					3,
	["gameSetDescription"] =						3,
	["gameSetJoinable"] =							3,
	["gameSetTitle"] =								3,
	["gameTagAdd"] =								3,
	["gameTagRemove"] =								3,
	["gameTagSet"] =								3,
	["runOnGameDeath"] =							0,
	["runOnGameJoin"] =								0,
	["runOnGameLeave"] =							0,
	["runOnGameRequestResponse"] =					0,
	["runOnGameRespawn"] =							0
}

--1: Only functions when you have not started a game.
--2: Only functions when you have started a game.
--3: Only functions when the chip has started a game.
--4: Only functions when the chip has started a game, and the target player has not blocked you.
--5: Only functions when the chip has started a game, and the target player is part of the game.
--6: Only functions when the chip had previously started a game.

local translate = include("wire_game_core/includes/translate.lua")
local wip_tag = translate("wire_game_core.e2helper.wip.tag")

--negative if they are wip
--bool if they have a special WIP message
for name, data in pairs(function_descriptions) do
	local method
	local parsed = string.Replace(name, ":", ".")
	local wip
	local wip_prefix
	
	if istable(data) then
		method = math.abs(data[1])
		wip = data[1] < 0
		wip_prefix = data[2]
	else
		method = math.abs(data)
		wip = data < 0
	end
	
	E2Helper.Descriptions[name] = translate(wip and "wire_game_core.e2helper.wip" or "wire_game_core.e2helper", {
		description = translate("wire_game_core.e2." .. parsed),
		prefix = method == 0 and "" or translate("wire_game_core.e2helper." .. math.abs(method)),
		wip = wip_prefix and translate("wire_game_core.e2helper.wip.prefixed", {
			text = translate("wire_game_core.e2_wip." .. parsed),
			wip = wip_tag
		}) or wip and wip_tag or nil
	})
end

--clean up! probably don't need to do this, lua's gc is smart
function_descriptions = nil