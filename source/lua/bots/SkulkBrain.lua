
Script.Load("lua/bots/PlayerBrain.lua")
Script.Load("lua/bots/SkulkBrain_Data.lua")

------------------------------------------
--
------------------------------------------
class 'SkulkBrain' (PlayerBrain)

function SkulkBrain:Initialize()

    PlayerBrain.Initialize(self)
    self.senses = CreateSkulkBrainSenses()
--  $defaultvalue false
    self.targettedForDebug = false
    local pause = math.random() * 10 -- ???
    self.nextAttackTime = 0
end

function SkulkBrain:GetExpectedPlayerClass()
    return "Skulk"
end

function SkulkBrain:GetExpectedTeamNumber()
    return kAlienTeamType
end

function SkulkBrain:GetActions()
-- $defaultvalue no line
--    self.targettedForDebug = true
    return kSkulkBrainActions
end

function SkulkBrain:GetSenses()
-- $defaultvalue no line
--    self.targettedForDebug = true
    return self.senses
end
