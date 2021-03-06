--[[
 File: lua/bots/BotTeamController.lua

 Description: This Singleton controls how player bots get assigned automatically to the playing teams.
    The controller only starts to assign bots if there is a human player in any of the playing teams
    and if the given maxbot value is et higher than 0. In case the last human player left the controller
    will also remove all bots

 Creator: Sebastian Schuck (ghoulofgsg9@gmail.com)

 Copyright (c) 2015, Unknown Worlds Entertainment, Inc.
]]
class 'BotTeamController'

BotTeamController.MaxBots = 0

--[[
-- Returns how many humans and bots given team has
 ]]
function BotTeamController:GetPlayerNumbersForTeam(teamNumber)
    PROFILE("BotTeamController:GetPlayerNumbersForTeam")

    local botNum = 0
    local humanNum = 0

    local team = GetGamerules():GetTeam(teamNumber)

    local function count(player)
        local client = player:GetClient()
        if client and not client:GetIsVirtual() then
            humanNum = humanNum + 1
        end
    end

    for _, bot in ipairs(gServerBots) do
        if bot:GetTeamNumber() == teamNumber then
            botNum = botNum + 1
        end
    end

    team:ForEachPlayer(count)
    return humanNum, botNum
end

function BotTeamController:GetCommanderBot(teamIndex)
    for _, commander in ipairs(gCommanderBots) do
        if commander.team == teamIndex then
            return commander
        end
    end
end

function BotTeamController:GetTeamHasCommander(teamNumber)
    local commandStructures = GetEntitiesForTeam("CommandStructure", teamNumber)

    for _, commandStructure in ipairs(commandStructures) do
        if commandStructure.occupied or commandStructure.gettingUsed then return true end
    end

    return false
end

function BotTeamController:NeededCommanders()
    local needed = 0

    if self.addCommanders then
        if not self:GetTeamHasCommander(kTeam1Index) then
            needed = needed + 1
        end

        if not self:GetTeamHasCommander(kTeam2Index) then
            needed = needed + 1
        end
    end

    return needed
end

function BotTeamController:AddBot(teamIndex)
    if self.addCommander and not self:GetTeamHasCommander(teamIndex) and not self:GetCommanderBot(teamIndex) then
        OnConsoleAddBots(nil, 1, teamIndex, "com")
    else
        OnConsoleAddBots(nil, 1, teamIndex)
    end
end

function BotTeamController:RemoveBot(teamIndex)
    OnConsoleRemoveBots(nil, 1, teamIndex)
end

--[[
-- Adds/removes a bot if needed, calling this method will trigger a recursive loop
-- over the PostJoinTeam method rebalancing the bots.
 ]]
function BotTeamController:UpdateBots()
    PROFILE("BotTeamController:UpdateBots")

    if self.MaxBots < 1 then return end --BotTeamController is disabled

    local team1HumanNum, team1BotsNum = self:GetPlayerNumbersForTeam(kTeam1Index)
    local team2HumanNum, team2BotsNum = self:GetPlayerNumbersForTeam(kTeam2Index)

    local team1Count = team1BotsNum + team1HumanNum
    local team2Count = team2BotsNum + team2HumanNum

    local humanCount = team1HumanNum + team2HumanNum
    local maxTeamBots = math.ceil(self.MaxBots / 2)

    --Update Team 1
    if (team1Count > maxTeamBots or humanCount == 0) and team1BotsNum > 0 then
        if humanCount == 0 or not self.addCommander or team1BotsNum > 1 or not self:GetCommanderBot(kTeam1Index) then
            self:RemoveBot(kTeam1Index)
        end
    elseif team1Count < maxTeamBots and humanCount > 0 then
        self:AddBot(kTeam1Index)
    end

    --Update Team 2
    if (team2Count > maxTeamBots or humanCount == 0) and team2BotsNum > 0 then
        if humanCount == 0 or not self.addCommander or team2BotsNum > 1 or not self:GetCommanderBot(kTeam2Index) then
            self:RemoveBot(kTeam2Index)
        end
    elseif team2Count < maxTeamBots and humanCount > 0 then
        self:AddBot(kTeam2Index)
    end

end

--[[
--Sets the amount of maximal allowed bots totally (without considering the amount of human players)
 ]]
function BotTeamController:SetMaxBots(newMaxBots, com)
    self.MaxBots = newMaxBots
    self.addCommander = com

    if newMaxBots == 0 then
        while gServerBots[1] do
            gServerBots[1]:Disconnect()
        end
    end
end
