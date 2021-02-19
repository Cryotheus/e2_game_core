local PANEL = {}

--panel functions
function PANEL:AddEntry(master_index, game_settings)
	local game_entry = self.GameEntries[master_index]
	
	if not IsValid(game_entry) then game_entry = vgui.Create("WGCBrowserGameEntry", self) end
	
	self.GameEntries[master_index] = game_entry
	
	game_entry:Dock(TOP)
	game_entry:DockMargin(4, 4, 4, 0)
	
	game_entry.FrameBrowser = self.FrameBrowser
	
	game_entry:SetMasterIndex(master_index)
	game_entry:SetSettings(game_settings)
	game_entry:CalculateScore()
	
	return game_entry
end

function PANEL:CalculateScore(master_index)
	local game_entry = self.GameEntries[master_index]
	
	if game_entry then game_entry:CalculateScore() end
end

function PANEL:CalculateScores() for master_index, game_entry in pairs(self.GameEntries) do game_entry:CalculateScore() end end

function PANEL:GetEntry(master_index) return self.GameEntries[master_index] end

function PANEL:Init() self.GameEntries = {} end

function PANEL:PerformLayoutInternal()
	local canvas = self.pnlCanvas
	local canvas_height = canvas:GetTall()
	
	self:Rebuild()
	self.VBar:SetUp(self:GetTall(), canvas_height)
	self.VBar:SetSize(0, 0)
	
	--double rebuild; because I said so
	canvas:SetPos(0, self.VBar:GetOffset())
	canvas:SetWide(self:GetWide())
	self:Rebuild()
	
	--clamps scroll
	if canvas_height ~= self.pnlCanvas:GetTall() then self.VBar:SetScroll(self.VBar:GetScroll()) end
end

function PANEL:RemoveEntry(master_index)
	local game_entry = self.GameEntries[master_index]
	
	if game_entry then game_entry:Remove() end
	
	self.GameEntries[master_index] = nil
end

function PANEL:SetSettings(master_index, game_settings)
	local game_entry = self.GameEntries[master_index]
	
	if game_entry then game_entry:SetSettings(game_settings)
	else self:AddEntry(master_index, game_settings) end
end

derma.DefineControl("WGCBrowserGameEntryContainer", "A panel for [E2] Game Core, holds game entries.", PANEL, "DScrollPanel")