
Script.Load("lua/bots/BotDebug.lua")
Script.Load("lua/bots/BotUtils.lua")
Script.Load("lua/bots/CommonActions.lua")
Script.Load("lua/bots/BrainSenses.lua")
Script.Load("lua/bots/TeamBrain.lua")
Script.Load("lua/bots/BotAim.lua")

local kUpgrades = {
  kTechId.Crush,
  kTechId.Carapace,
  kTechId.Regeneration,

  kTechId.Vampirism,
  kTechId.Aura,
  kTechId.Focus,

  kTechId.Silence,
  kTechId.Celerity,
  kTechId.Adrenaline,
}

------------------------------------------
--  More urgent == should really attack it ASAP
------------------------------------------
local immediateThreats = {
  [kMinimapBlipType.Marine] = true,
  [kMinimapBlipType.JetpackMarine] = true,
  [kMinimapBlipType.Exo] = true,
  [kMinimapBlipType.Sentry] = true
}

local function GetAttackUrgency(bot, mem)

  -- See if we know whether if it is alive or not
  local ent = Shared.GetEntity(mem.entId)
  if not HasMixin(ent, "Live") or not ent:GetIsAlive() then
    return 0.0
  end

  local botPos = bot:GetPlayer():GetOrigin()
  local targetPos = ent:GetOrigin()
  local distance = botPos:GetDistance(targetPos)

  if mem.btype == kMinimapBlipType.PowerPoint then
    local powerPoint = ent
    if powerPoint and powerPoint:GetIsSocketed() then
      return 0.35 
    else
      return 0
    end
  end

  if immediateThreats[mem.btype] then
    if distance < 10 then
      -- Attack the nearest immediate threat (urgency will be 1.1 - 2)
      return 1 + 1 / math.max(distance, 1)
    elseif distance < 20 then
      return 1 / math.max(distance, 1)
    end
  end

  --  -- No immediate threat - load balance!
  --  local numOthers = bot.brain.teamBrain:GetNumAssignedTo( mem,
  --      function(otherId)
  --        if otherId ~= bot:GetPlayer():GetId() then
  --          return true
  --        end
  --        return false
  --      end)

  --  local urgencies = {
  --    -- Active threats
  --    [kMinimapBlipType.Marine] =      numOthers >= 4 and 0.6 or 1,
  --    [kMinimapBlipType.JetpackMarine] =    numOthers >= 4 and 0.7 or 1.1,
  --    [kMinimapBlipType.Exo] =        numOthers >= 6 and 0.8 or 1.2,
  --    [kMinimapBlipType.Sentry] =      numOthers >= 3 and 0.5 or 0.95,
  --
  --    -- Structures
  --    [kMinimapBlipType.ARC] =        numOthers >= 4 and 0.4 or 0.9,
  --    [kMinimapBlipType.CommandStation] =  numOthers >= 8 and 0.3 or 0.85,
  --    [kMinimapBlipType.PhaseGate] =      numOthers >= 4 and 0.2 or 0.8,
  --    [kMinimapBlipType.Observatory] =    numOthers >= 3 and 0.2 or 0.75,
  --    [kMinimapBlipType.Extractor] =      numOthers >= 3 and 0.2 or 0.7,
  --    [kMinimapBlipType.InfantryPortal] =  numOthers >= 3 and 0.2 or 0.6,
  --    [kMinimapBlipType.PrototypeLab] =    numOthers >= 3 and 0.2 or 0.55,
  --    [kMinimapBlipType.Armory] =      numOthers >= 3 and 0.2 or 0.5,
  --    [kMinimapBlipType.RoboticsFactory] =  numOthers >= 3 and 0.2 or 0.5,
  --    [kMinimapBlipType.ArmsLab] =      numOthers >= 3 and 0.2 or 0.5,
  --    [kMinimapBlipType.MAC] =        numOthers >= 2 and 0.2 or 0.4,
  --  }

  --  if urgencies[ mem.btype ] ~= nil then
  --    return urgencies[ mem.btype ]
  --  end

  return 0.0

end


local function PerformAttackEntity( eyePos, bestTarget, bot, brain, move )

  assert( bestTarget )

  local marinePos = bestTarget:GetOrigin()

  local doFire = false

  local distance = eyePos:GetDistance(marinePos)

  local player = bot:GetPlayer()
  local team = player:GetTeamNumber()
  local isFriendly = HasMixin(bestTarget, "Team") and bestTarget:GetTeamNumber() == team

  local botCanSeeTarget = GetBotCanSeeTarget(player, bestTarget)

  bot:GetMotion():SetDesiredMoveTarget(nil)
  
  if botCanSeeTarget and (distance < 5) then
    bot:GetMotion():SetDesiredViewTarget(bestTarget:GetEngagementPoint())
    move.commands = AddMoveCommand(move.commands, Move.SecondaryAttack)
    if GetDistanceToTouch(eyePos, bestTarget) > 2 then
      bot:GetMotion():SetDesiredMoveTarget(marinePos)
    end
  elseif (not isFriendly) and (distance < 25) and botCanSeeTarget then
    -- jitter view target a little bit
    -- local jitter = Vector( math.random(), math.random(), math.random() ) * 0.1
    bot:GetMotion():SetDesiredViewTarget(bestTarget:GetEngagementPoint())
    move.commands = AddMoveCommand(move.commands, Move.PrimaryAttack)
--        if GetDistanceToTouch(eyePos, bestTarget) < 10 then
--          -- Stop running at the structure when close enough
--          bot:GetMotion():SetDesiredMoveTarget(nil)
--        end
  elseif isFriendly then
    bot:GetMotion():SetDesiredViewTarget(nil)
    bot:GetMotion():SetDesiredMoveTarget(marinePos)

    -- Occasionally jump
    if math.random() < 0.01 and bot:GetPlayer():GetIsOnGround() then
      move.commands = AddMoveCommand( move.commands, Move.Jump )
      if distance < 15 then
        -- When approaching, try to jump sideways
        player.timeOfJump = Shared.GetTime()
        player.jumpOffset = nil
      end
    end
  end

  if player.timeOfJump ~= nil and Shared.GetTime() - player.timeOfJump < 0.5 then

    if player.jumpOffset == nil then

      local botToTarget = GetNormalizedVectorXZ(marinePos - eyePos)
      local sideVector = botToTarget:CrossProduct(Vector(0, 1, 0))
      if math.random() < 0.5 then
        player.jumpOffset = botToTarget + sideVector
      else
        player.jumpOffset = botToTarget - sideVector
      end
      bot:GetMotion():SetDesiredViewTarget( bestTarget:GetEngagementPoint() )

    end

    bot:GetMotion():SetDesiredMoveDirection( player.jumpOffset )
  end

end

local function PerformAttack( eyePos, mem, bot, brain, move )

  assert( mem )

  local target = Shared.GetEntity(mem.entId)

  if target ~= nil then
    PerformAttackEntity( eyePos, target, bot, brain, move )
  else
    -- mem is too far to be relevant, so move towards it
    bot:GetMotion():SetDesiredViewTarget(nil)
    bot:GetMotion():SetDesiredMoveTarget(mem.lastSeenPos)
  end

  brain.teamBrain:AssignBotToMemory(bot, mem)

end

------------------------------------------
--  Each want function should return the fuzzy weight,
-- along with a closure to perform the action
-- The order they are listed matters - actions near the beginning of the list get priority.
------------------------------------------
kGorgeBrainActions =
  {

    ------------------------------------------
    --
    ------------------------------------------
    function(bot, brain)
      return { name = "debug idle", weight = 0.001,
        perform = function(move)
          bot:GetMotion():SetDesiredMoveTarget(nil)
          -- there is nothing obvious to do.. figure something out
          -- like go to the marines, or defend
        end }
    end,

    ------------------------------------------
    --
    ------------------------------------------
    CreateExploreAction( 0.01, function(pos, targetPos, bot, brain, move)
      bot:GetMotion():SetDesiredMoveTarget(targetPos)
      bot:GetMotion():SetDesiredViewTarget(nil)
    end ),

    ------------------------------------------
    --
    ------------------------------------------
    function(bot, brain)
      local name = "evolve"

      local weight = 0.0
      local player = bot:GetPlayer()
      local desiredUpgrades = {}
      local now = Shared.GetTime()        
      if (bot.nextCheckEvolveTime == nil) or (bot.nextCheckEvolveTime > now) then
        bot.nextCheckEvolveTime = now + 3
        local player = bot:GetPlayer()
        local s = brain:GetSenses()
        local res = player:GetPersonalResources()
  
        local distanceToNearestThreat = s:Get("nearestThreat").distance
  
        if player:GetIsAllowedToBuy() and
           (distanceToNearestThreat == nil or distanceToNearestThreat > 20)
           and (not EntityIsVisible(player)) 
           and (player.GetIsInCombat == nil or not player:GetIsInCombat()) then
  
          -- Safe enough to try to evolve
  
          local existingUpgrades = player:GetUpgrades()
  
          local avaibleUpgrades = player.lifeformUpgrades
  
          if not avaibleUpgrades then
            avaibleUpgrades = {}
  
            for i = 0, 2 do
              table.insert(avaibleUpgrades, kUpgrades[math.random(1,3) + i * 3])
            end
  
            if player.lifeformEvolution then
              table.insert(avaibleUpgrades, player.lifeformEvolution)
            end
  
            player.lifeformUpgrades = avaibleUpgrades
          end
  
          for i = 1, #avaibleUpgrades do
            local techId = avaibleUpgrades[i]
            local techNode = player:GetTechTree():GetTechNode(techId)
  
            local isAvailable = false
            local cost = 0
            if techNode ~= nil then
              isAvailable = techNode:GetAvailable(player, techId, false)
              cost = LookupTechData(techId, kTechDataGestateName) and GetCostForTech(techId) or LookupTechData(kTechId.Gorge, kTechDataUpgradeCost, 0)
            end
  
            if not player:GetHasUpgrade(techId) and isAvailable and res - cost > 0 and
              GetIsUpgradeAllowed(player, techId, existingUpgrades) and
              GetIsUpgradeAllowed(player, techId, desiredUpgrades) then
              res = res - cost
              table.insert(desiredUpgrades, techId)
            end
          end
  
          if  #desiredUpgrades > 0 then
            weight = 100.0
          end
        end
      end
      return { name = name, weight = weight,
        perform = function(move)
          player:ProcessBuyAction( desiredUpgrades )
        end }

    end,

    ------------------------------------------
    --
    ------------------------------------------
    function(bot, brain)
      local name = "defence"
      local subject = bot:GetPlayer()
      local eyePos = subject:GetEyePos()

      local memories = GetTeamMemories(subject:GetTeamNumber())
      local bestUrgency, bestMem = GetMaxTableEntry( memories,
        function( mem )
          return GetAttackUrgency( bot, mem )
        end)

      local weapon = subject:GetActiveWeapon()
      local canAttack = weapon ~= nil and weapon:isa("SpitSpray")

      local weight = 0.0

      if canAttack and bestMem ~= nil then

        local dist = 0.0
        local entity = Shared.GetEntity(bestMem.entId)
        if (entity ~= nil) and (GetBotCanSeeTarget(subject, entity)) then
          dist = GetDistanceToTouch(eyePos, entity)
          weight = EvalLPF( dist, {
            { 0.0, EvalLPF( bestUrgency, {
              { 0.0, 0.0 },
              { 10.0, 25.0 }
            })},
            { 10.0, EvalLPF( bestUrgency, {
              { 0.0, 0.0 },
              { 10.0, 5.0 }
            })},
            { 100.0, 0.0 } })
        end
      end

      return { name = name, weight = weight,
        perform = function(move)
          PerformAttack( eyePos, bestMem, bot, brain, move )
        end }
    end,

    ------------------------------------------
    --
    ------------------------------------------
    function(bot, brain)
      local name = "pheromone"

      local subject = bot:GetPlayer()
      local eyePos = subject:GetEyePos()

      local pheromones = EntityListToTable(Shared.GetEntitiesWithClassname("Pheromone"))
      local bestPheromoneLocation = nil
      local bestValue = 0

      for p = 1, #pheromones do

        local currentPheromone = pheromones[p]
        if currentPheromone then
          local techId = currentPheromone:GetType()

          if techId == kTechId.ExpandingMarker or techId == kTechId.ThreatMarker then

            local location = currentPheromone:GetOrigin()
            local locationOnMesh = Pathing.GetClosestPoint(location)
            local distanceFromMesh = location:GetDistance(locationOnMesh)

            if distanceFromMesh > 0.001 and distanceFromMesh < 2 then

              local distance = eyePos:GetDistance(location)

              if currentPheromone.visitedBy == nil then
                currentPheromone.visitedBy = {}
              end

              if not currentPheromone.visitedBy[bot] then

                if distance < 5 then
                  currentPheromone.visitedBy[bot] = true
                else

                  -- Value goes from 5 to 10
                  local value = 5.0 + 5.0 / math.max(distance, 1.0) - #(currentPheromone.visitedBy)

                  if value > bestValue then
                    bestPheromoneLocation = locationOnMesh
                    bestValue = value
                  end

                end

              end

            end

          end

        end

      end

      local weight = EvalLPF( bestValue, {
        { 0.0, 0.0 },
        { 10.0, 1.0 }
      })

      return { name = name, weight = weight,
        perform = function(move)
          bot:GetMotion():SetDesiredMoveTarget(bestPheromoneLocation)
          bot:GetMotion():SetDesiredViewTarget(nil)
        end }
    end,

    ------------------------------------------
    --
    ------------------------------------------
    function(bot, brain)
      local name = "order"

      local subject = bot:GetPlayer()
      local order = bot:GetPlayerOrder()

      local weight = 0.0
      if order ~= nil then
        weight = 10.0
      end

      return { name = name, weight = weight,
        perform = function(move)
          if order then

            local target = Shared.GetEntity(order:GetParam())

            if target ~= nil and order:GetType() == kTechId.Attack then

              PerformAttackEntity( subject:GetEyePos(), target, bot, brain, move )

            else

              if brain.debug then
                DebugPrint("unknown order type: %s", ToString(order:GetType()) )
              end

              bot:GetMotion():SetDesiredMoveTarget( order:GetLocation() )
              bot:GetMotion():SetDesiredViewTarget( nil )

            end
          end
        end }
    end,

    function(bot, brain)
      local name = "spray"

      local subject = bot:GetPlayer()
      local senses = brain:GetSenses()
      local eyePos = subject:GetEyePos()

      local nearestSprayNeed = senses:Get("nearestSprayNeed")
      local weight = nearestSprayNeed.weight
      local entity = nearestSprayNeed.entity
      if entity ~= nil then
        entity = Shared.GetEntity(entity.entId)
      end

      if (weight == nil) or (entity == nil) then
        weight = 0
        entity = nil
      end

      if (weight ~= 0) and (entity ~= nil) and (entity ~= subject) then
      --DebugLine(eyePos, entity, 0.0, 1, 0, 0, 1, true)
      --DebugPrint("Nearest Spray Needed2: %.4f, %s", weight, EntityToString(entity))
      end


      return { name = name, weight = weight,
        perform = function(move)
          PerformAttack( eyePos, nearestSprayNeed.entity, bot, brain, move )
        end }

    end,

    function(bot, brain)
      local name = "team"

      local subject = bot:GetPlayer()
      local senses = brain:GetSenses()
      local eyePos = subject:GetEyePos()
      local weight = 0
      local nearestTeam = senses:Get("nearestTeam")
      if (nearestTeam.nearestTeam) and (nearestTeam.distance > 0) then
--        DebugPrint("nearestTeam = %0.1f", nearestTeam.distance)
        local weight = EvalLPF(math.max(1.0, nearestTeam.distance), {
          {1.0, 3.0},
          {5.0, 1.0},
          {50.0, 0.3},
          {300, 0.1}
        })
      end
      return { name = name, weight = weight,
        perform = function(move)
          -- DebugPrint("PERFORM MOVE TO FRIENDLY ACTION")
          local origin = nearestTeam.nearestTeam:GetOrigin()
          bot:GetMotion():SetDesiredMoveTarget(origin)
          bot:GetMotion():SetDesiredViewTarget(nil)
          --PerformAttack( eyePos, nearestTeam.entity, bot, brain, move )
        end
      }
    end
  }

------------------------------------------
--
------------------------------------------
function CreateGorgeBrainSenses()

  local s = BrainSenses()
  s:Initialize()

  s:Add("allThreats", function(db)
    local player = db.bot:GetPlayer()
    local team = player:GetTeamNumber()
    local memories = GetTeamMemories( team )
    return FilterTableEntries( memories,
      function( mem )
        local ent = Shared.GetEntity( mem.entId )
        if ent:isa("Player") or ent:isa("Sentry") then
          local isAlive = HasMixin(ent, "Live") and ent:GetIsAlive()
          local isEnemy = HasMixin(ent, "Team") and ent:GetTeamNumber() ~= team
          return isAlive and isEnemy
        else
          return false
        end
      end)
  end)

  s:Add("nearestThreat", function(db)
    local allThreats = db:Get("allThreats")
    local player = db.bot:GetPlayer()
    local playerPos = player:GetOrigin()

    local distance, nearestThreat = GetMinTableEntry( allThreats,
      function( mem )
        local origin = mem.origin
        if origin == nil then
          origin = Shared.GetEntity(mem.entId):GetOrigin()
        end
        return playerPos:GetDistance(origin)
      end)

    return {distance = distance, memory = nearestThreat}
  end)

  s:Add("allTeam", function(db)
    local player = db.bot:GetPlayer()
    local playerId = player:GetId()
    local team = player:GetTeamNumber()
    local memories = GetTeamMemories( team )
    return FilterTableEntries( memories,
      function( mem )
        local ent = Shared.GetEntity( mem.entId )
        if (playerId ~= mem.entId) and ent:isa("Player") then
          local isAlive = HasMixin(ent, "Live") and ent:GetIsAlive()
          local isFriendly = HasMixin(ent, "Team") and (ent:GetTeamNumber() == team)
          return isAlive and isFriendly
        else
          return false
        end
      end)
  end)

  s:Add("nearestTeam", function(db)
    local allTeam = db:Get("allTeam")
    local player = db.bot:GetPlayer()
    local playerPos = player:GetOrigin()

    local distance, nearestTeam = GetMinTableEntry( allTeam,
      function( mem )
        local origin = mem.origin
        if origin == nil then
          origin = Shared.GetEntity(mem.entId):GetOrigin()
        end
        local distance = playerPos:GetDistance(origin)
        if (-0.001 < distance) and (distance < 0.001) then
          distance = 100000
        end
        return distance
      end)

    return {distance = distance, nearestTeam = nearestTeam}
  end)

  s:Add("allSprayNeedWeights", function(db)
    local player = db.bot:GetPlayer()
    local team = player:GetTeamNumber()
    local memories = GetTeamMemories( team )
    return FilterTableEntries( memories,
      function( mem )
        local ent = Shared.GetEntity( mem.entId )
        local isAlive = HasMixin(ent, "Live") and ent:GetIsAlive()
        local isFriendly = HasMixin(ent, "Team") and ent:GetTeamNumber() == team
        local health = 0
        if isAlive then
          health = ent:GetHealthFraction()
        else
          health = 1
        end
        if isAlive and isFriendly then
          if ent:isa("Construction") and (ent:GetBuiltFraction() < 1) then
            return true
          else
            return (health < 1)
          end
        end
      end)
  end)

  s:Add("nearestSprayNeed", function(db)
    local allSprayNeedWeights = db:Get("allSprayNeedWeights")
    local player = db.bot:GetPlayer()
    local playerPos = player:GetOrigin()

    local weight, entity = GetMaxTableEntry( allSprayNeedWeights,
      function( mem )
        local origin = mem.origin
        local ent = Shared.GetEntity(mem.entId)
        if ent == player then
          return 0
        end
        if origin == nil then
          origin = ent:GetOrigin()
        end
        local distance = playerPos:GetDistance(origin)
        local distanceWeight = 0;
        if ent:isa("Onos") then
          distanceWeight = EvalLPF( distance, {
            { 0.0, 25.0 },
            { 50.0, 10.0 },
            { 150.0, 0.0}
          })
        elseif ent:isa("Hive") then
          distanceWeight = EvalLPF( distance, {
            { 0.0, 15.0 },
            { 50.0, 5.0 },
            { 150.0, 0.0}
          })
        elseif ent:isa("Harvester") or ent:isa("Crag") or ent:isa("Hive") then
          distanceWeight = EvalLPF( distance, {
            { 0.0, 7.0 },
            { 50.0, 3.0 },
            { 100.0, 0.0}
          })
        elseif ent:isa("Fade") then
          distanceWeight = EvalLPF( distance, {
            { 0.0, 5.0 },
            { 5.0, 2.0 },
            { 10.0, 0.0}
          })
        elseif ent:isa("Skulk") then
          distanceWeight = EvalLPF( distance, {
            { 0.0, 4.0 },
            { 10.0, 2.0 },
            { 20.0, 0.0}
          })
        elseif ent:isa("Cyst") then
          distanceWeight = EvalLPF( distance, {
            { 0.0, 2.0 },
            { 5.0, 1.0 },
            { 10.0, 0.0}
          })
        else
          distanceWeight = EvalLPF( distance, {
            { 0.0, 10.0 },
            { 10.0, 1.0 },
            { 30.0, 0.0}
          })
        end

        -- kPrint("type = %s, distance = %d, distanceWeight = %.6f", EntityToString(ent), distance, distanceWeight)

        local health = 1;
        if ent:isa("Live") then
          health = ent:GetHealthFraction()
          --Print("player health = %.4f", health)
        elseif HasMixin(ent, "Construct") and not ent:GetIsBuilt() then
          health = ent.buildFraction
        end
        --          if health < 0.01 then
        --            health = 1
        --          end
        local k = 1.0
        if ent:isa("Crag") then
          k = 3
        elseif ent:isa("Onos") then
          k = 2
        elseif ent:isa("Hive") then
          k = 2
        end
        local weight = distanceWeight * (1 - health) * k

        return weight
      end)

    return {weight = weight, entity = entity}
  end)


  return s
end





--function CreateGorgeBrainReferences()


--  local prefs = {};


--  prefs.OnosSupportFraction = 1 + math.random()


--  prefs.HiveSupportFraction = 1 + math.random()


--  return prefs


--end


--
