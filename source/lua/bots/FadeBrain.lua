
Script.Load("lua/bots/PlayerBrain.lua")
Script.Load("lua/bots/FadeBrain_Data.lua")

------------------------------------------
--
------------------------------------------
class 'FadeBrain' (PlayerBrain)

function FadeBrain:Initialize()

    PlayerBrain.Initialize(self)
    self.senses = CreateFadeBrainSenses()

end

function FadeBrain:GetExpectedPlayerClass()
    return "Fade"
end

function FadeBrain:GetExpectedTeamNumber()
    return kAlienTeamType
end

function FadeBrain:GetActions()
    return kFadeBrainActions
end

function FadeBrain:GetSenses()
    return self.senses
end
