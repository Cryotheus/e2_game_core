resource.AddFile("materials/icon64/game_core_browser_icon.png") --used for the context menu icon, first version
resource.AddFile("materials/vgui/wire_game_core/icon.png") --used for the icon in the game browsers
resource.AddFile("materials/vgui/wire_game_core/icon.png") --used for the icon in the game browsers
resource.AddFile("resource/localization/en/wire_game_core.properties") --needed for all the descriptions and stuff

--at this point I am thinking of grouping some less commonly used ones together and sending a uint to identify what its purpose is
--this would cut down on the amount of network strings I am using, but increase code complexity a little bit
util.AddNetworkString("wire_game_core_block")
util.AddNetworkString("wire_game_core_block_update")
util.AddNetworkString("wire_game_core_join")
util.AddNetworkString("wire_game_core_leave")
util.AddNetworkString("wire_game_core_message")
util.AddNetworkString("wire_game_core_masters")
util.AddNetworkString("wire_game_core_request")
util.AddNetworkString("wire_game_core_sounds")
util.AddNetworkString("wire_game_core_sync")