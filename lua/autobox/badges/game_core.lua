--for the autobox server!
--join at 74.91.119.157:27015
--							BadID,		 Name,			 Desc,											  Goal,Icon, 													  Prog,	GetProg
autobox.badge:RegisterBadge("game_core", "Game Creator", "Have 4 players play your game simultaneously.", 4, "materials/autobox/scoreboard/badges/game_core/creator.png", true, function(ply)
	local badge_stages = {
		[0] = {
			Goal = 4,
			Desc = "Have 4 players play your game simultaneously.",
			Icon = "materials/autobox/scoreboard/badges/game_core/creator.png",
			Name = "Game Creator",
			ProgName = "host a 4 player game",
			Has = false,
			HasMax = false
		},
		
		[4] = {
			Goal = 10,
			Desc = "Have 4 players play your game simultaneously",
			Icon = "materials/autobox/scoreboard/badges/game_core/creator.png",
			Name = "Game Creator",
			ProgName = "host a 4 player game",
			Has = true,
			HasMax = false
		},
		
		[10] = {
			Goal = 20,
			Desc = "Have 10 players play your game simultaneously",
			Icon = "materials/autobox/scoreboard/badges/game_core/host.png",
			Name = "Game Hoster",
			ProgName = "host a 10 player game",
			Has = true,
			HasMax = false
		},
		
		[20] = {
			Goal = 20,
			Desc = "Have 20 players play your game simultaneously",
			Icon = "materials/autobox/scoreboard/badges/game_core/master.png",
			Name = "Game Master",
			ProgName = "host a 20 player game",
			Has = true,
			HasMax = true
		}
	}
	
	--we can use autobox.badge:ShowNotice(ply, "game_core") to let them know their progress
	
	local badge_values = {4, 10, 20}
	local progress = ply:AAT_GetBadgeProgress("game_core")
	local progress_stage = 0
	
	for index, stage in ipairs(badge_values) do
		if progress >= stage then progress_stage = stage
		else break end
	end
	
	local badge = badge_stages[progress_stage]
	
	badge.GetVals = table.Copy(badge_values)
	
	if CLIENT then badge.Icon = Material(badge.Icon) end
	
	return badge
end)

resource.AddFile("materials/autobox/scoreboard/badges/game_core/creator.png")
resource.AddFile("materials/autobox/scoreboard/badges/game_core/host.png")
resource.AddFile("materials/autobox/scoreboard/badges/game_core/master.png")