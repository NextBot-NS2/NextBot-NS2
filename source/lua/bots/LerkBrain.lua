
Script.Load("lua/bots/PlayerBrain.lua")
Script.Load("lua/bots/LerkBrain_Data.lua")

------------------------------------------
--
------------------------------------------
class 'LerkBrain' (PlayerBrain)

function LerkBrain:Initialize()

    PlayerBrain.Initialize(self)
    self.senses = CreateLerkBrainSenses()

end

function LerkBrain:GetExpectedPlayerClass()
    return "Lerk"
end

function LerkBrain:GetExpectedTeamNumber()
    return kAlienTeamType
end

function LerkBrain:GetActions()
    return kLerkBrainActions
end

function LerkBrain:GetSenses()
    return self.senses
end
