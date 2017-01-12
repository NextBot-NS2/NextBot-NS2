
Script.Load("lua/bots/PlayerBrain.lua")
Script.Load("lua/bots/LerkBrain_Data.lua")

------------------------------------------
--
------------------------------------------
class 'LerkBrain' (PlayerBrain)

function LerkBrain:Initialize()

    PlayerBrain.Initialize(self)
    self.desiredHeight = 1.5
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

function LerkBrain:Update(bot, move)
  --$need refactoring
  local motion = bot:GetMotion()
  motion.desiredHeight = self.desiredHeight
  motion.addHeight = 0
  motion.maxStraightLength = 20
  motion.desiredMoveUpdatePeriod = 0.3
  PlayerBrain.Update(self, bot, move)
end
