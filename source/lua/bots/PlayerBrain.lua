
------------------------------------------
--  Base class for bot brains
------------------------------------------

Script.Load("lua/bots/BotUtils.lua")
Script.Load("lua/bots/BotDebug.lua")

gBotDebug:AddBoolean("debugall", true)

------------------------------------------
--  Globals
------------------------------------------

kPlayerBrainTickrate = 10
kTickDelta = 1 / kPlayerBrainTickrate

kBrainStatus = {IDLE = 0, INTEREST = 1, ALERTNESS = 2, ALERT = 3, AGGRESSION = 4, ESCAPE = 5, REPLEXITY = 6}


class 'PlayerBrain'

function PlayerBrain:Initialize()

    self.lastAction = nil
    -- to exclude duplicate messages
    self.status = kBrainStatus.IDLE
    -- постоянные черты характера
    -- tickDelta при велечине ~= 0.1 вызывает странные эффекты при вызове GetActiveWeapon - он возвращает nil
    self.tickDelta = kTickDelta -- + kTickDelta * math.random() / 4
    self.characterTraits = {
      aggressionLevel = 0.5, -- например, влияет уровень преследования противника
      caution = {
        min = 0.3,
        max = 0.8, -- уровень тревожности, в противоположность песпечности - как часто будет оглядываться, например
        decreaseSpeed = 0.1/15 -- units/sec
      },
      reaction = {
        minTicks = 150, 
        maxTicks = 500
      },
      aiming = {
        -- rad/msec скорость наведения на цель
        maxAngleSpeed = 3 / 50,
        -- рысканье прицела - сколько рандомно добавится или убавится к последнему движению виртуальной мыши
        accuracy = 0.9
      },
      diligence = 0.5,
      assistLevel = 0.5,
      confidence = {
        min = 0.3,
        max = 0.8
      }
    }
    -- глобальное состояние 
    self.overallStatus = kBrainStatus.IDLE
    self.status = {
      -- уверенность
      confidence = 1,
      reactionTicks = self.characterTraits.reaction.maxTicks,
      caution = (self.characterTraits.caution.min + self.characterTraits.caution.max) / 2,
      currentOrderWeight = 2
    }
    self.lastOrder = {
      time = 0,
      weight = 0,
    }
end

function PlayerBrain:GetCurrentOrderWeight()
  local orderDelta = Shared.GetTime() - self.lastOrder.time
  local weight = self.lastOrder.weight - orderDelta * 0.3
  weight = (weight < 2) and 2 or weight
  self.status.currentOrderWeight = weight
  return weight
end

function PlayerBrain:GetShouldDebug(bot)

    ------------------------------------------
    --  This code is for Player-types, commanders should override this
    ------------------------------------------
    -- If commander-selected, turn debug on
    local isSelected = bot:GetPlayer():GetIsSelected( kMarineTeamType ) or bot:GetPlayer():GetIsSelected( kAlienTeamType )

    if isSelected and gDebugSelectedBots then
        return true
    elseif self.targettedForDebug then
        return true
    else
        return false
    end

end

function PlayerBrain:Update(bot, move)
    PROFILE("NPlayerBrain:Update")

    if gBotDebug:Get("spam") then
        DebugPrint("PlayerBrain:Update")
    end

    local player = bot:GetPlayer()

    if not player:isa( self:GetExpectedPlayerClass() )
    or player:GetTeamNumber() ~= self:GetExpectedTeamNumber() then
        bot.brain = nil
        return
    end

    local time = Shared.GetTime()

    local skipUpdate = false
    if self.lastAction and self.nextMoveTime 
            and self.lastAction.name ~= "attack" and self.nextMoveTime > time then
      skipUpdate = true
    end

    if skipUpdate then
      return
    end

    self.debug = self:GetShouldDebug(bot)

    if self.debug then
        DebugPrint("-- BEGIN BRAIN UPDATE, player name = %s --", player:GetName())
    end

    self.teamBrain = GetTeamBrain( player:GetTeamNumber() )
--    self.teamBrain.Test()

    local bestAction = nil

    -- Prepare senses before action-evals use it
    assert( self:GetSenses() ~= nil )
    self:GetSenses():OnBeginFrame(bot)

    for actionNum, actionEval in ipairs( self:GetActions() ) do

        self:GetSenses():ResetDebugTrace()

        local action = actionEval(bot, self)
        assert( action.weight ~= nil )

        if self.debug then
            DebugPrint("weight(%s) = %0.2f. trace = %s",
                    action.name, action.weight, self:GetSenses():GetDebugTrace())
        end

        if bestAction == nil or action.weight > bestAction.weight then
            bestAction = action
        end
    end

    if bestAction ~= nil then
--        if bot:GetPlayer():isa("Marine") then
--          bot:PrintToChat(false, "selected action: " .. bestAction.name)
--        end
        if self.debug then
           DebugPrint("chose action: " .. bestAction.name)
        end


        bestAction.perform(move)
        self.lastAction = bestAction
        -- floatable next move time for load balance
        self.nextMoveTime = time + self.tickDelta

        if self.debug or gBotDebug:Get("debugall") then
            Shared.DebugColor( 0, 1, 0, 1 )
            Shared.DebugText( bestAction.name, player:GetEyePos()+Vector(-1,0,0), 0.0 )
        end
    end

end

function PlayerBrain:GetTeamBrain()
  return self.teamBrain
end
