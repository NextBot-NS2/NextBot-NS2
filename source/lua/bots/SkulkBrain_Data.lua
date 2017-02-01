
Script.Load("lua/bots/BotDebug.lua")
Script.Load("lua/bots/BotUtils.lua")
Script.Load("lua/bots/CommonActions.lua")
Script.Load("lua/bots/BrainSenses.lua")
Script.Load("lua/bots/TeamBrain.lua")
Script.Load("lua/bots/BotAim.lua")
Script.Load("lua/TechTree.lua")
Script.Load("lua/TechData.lua")

--local kUpgrades = {
--    kTechId.Crush,
--    kTechId.Carapace,
--    kTechId.Regeneration,
--        
--    kTechId.Vampirism,
--    kTechId.Aura,
--    kTechId.Focus,
--    
--    kTechId.Silence,
--    kTechId.Celerity,
--    kTechId.Adrenaline,
--}

local kEvolutions = {
--  kTechId.Lerk
--  kTechId.Gorge,
  kTechId.Lerk,
  kTechId.Fade,
  kTechId.Onos
}

local kLeapTime = 0.2

------------------------------------------
--  More urgent == should really attack it ASAP
------------------------------------------
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
        if powerPoint ~= nil and powerPoint:GetIsSocketed() then
            return 0.55
        else
            return 0
        end    
    end
        
    local immediateThreats = {
        [kMinimapBlipType.Marine] = true,
        [kMinimapBlipType.JetpackMarine] = true,
        [kMinimapBlipType.Exo] = true,    
        [kMinimapBlipType.Sentry] = true
    }
    
    if distance < 15 and immediateThreats[mem.btype] then
        -- Attack the nearest immediate threat (urgency will be 1.1 - 2)
        return 1 + 1 / math.max(distance, 1)
    end
    
    -- No immediate threat - load balance!
    local numOthers = bot.brain.teamBrain:GetNumAssignedTo( mem,
            function(otherId)
                if otherId ~= bot:GetPlayer():GetId() then
                    return true
                end
                return false
            end)

    --Other urgencies do not rank anything here higher than 1!
    local urgencies = {
        [kMinimapBlipType.ARC] =                numOthers >= 2 and 0.4 or 0.9,
        [kMinimapBlipType.CommandStation] =     numOthers >= 4 and 0.3 or 0.75,
        [kMinimapBlipType.PhaseGate] =          numOthers >= 2 and 0.2 or 0.9,
        [kMinimapBlipType.Observatory] =        numOthers >= 2 and 0.2 or 0.8,
        [kMinimapBlipType.Extractor] =          numOthers >= 2 and 0.2 or 0.7,
        [kMinimapBlipType.InfantryPortal] =     numOthers >= 2 and 0.2 or 0.6,
        [kMinimapBlipType.PrototypeLab] =       numOthers >= 1 and 0.2 or 0.55,
        [kMinimapBlipType.Armory] =             numOthers >= 2 and 0.2 or 0.5,
        [kMinimapBlipType.RoboticsFactory] =    numOthers >= 2 and 0.2 or 0.5,
        [kMinimapBlipType.ArmsLab] =            numOthers >= 3 and 0.2 or 0.6,
        [kMinimapBlipType.MAC] =                numOthers >= 1 and 0.2 or 0.4,
    }

    if urgencies[ mem.btype ] ~= nil then
        return urgencies[ mem.btype ]
    end

    return 0.0
    
end


local function PerformAttackEntity( eyePos, bestTarget, bot, brain, move )

    assert( bestTarget )

    local marinePos = bestTarget:GetOrigin()

    local player = bot:GetPlayer()
    local motion = bot:GetMotion()
    local now = Shared.GetTime()
    local weapon = player:GetActiveWeapon()
    local isParasite = (weapon ~= nil) and weapon:isa("Parasite")
    local isBite = (weapon ~= nil) and weapon:isa("BiteLeap")
    local targetIsMoveable = bestTarget:isa("Player")

    local targetPoint = bestTarget:GetEngagementPoint()
    local distance = eyePos:GetDistance(marinePos)
    motion:SetDesiredMoveTarget(marinePos)
    -- leap
--    Print(">>>>>>>>> 1 "..(GetTechTree(player:GetTeamNumber()):GetHasTech(kTechId.Leap) and "1" or "0"))
--    Print(">>>>>>>>> 2 "..(player:GetIsLeaping() and "1" or "0"))
--    Print(">>>>>>>>> 3 "..(((player.timeOfLeap or 0) + kLeapTime < now) and "1" or "0"))
--    bot:PrintToChat(string.format("IsTech: %d, IsLeaping: %d, IsNow: %d",
--      GetTechTree(player:GetTeamNumber()):GetHasTech(kTechId.Leap) and 1 or 0,
--      player:GetIsLeaping() and 1 or 0, 
--      ((player.timeOfLeap or 0) + kLeapTime < now) and 1 or 0))
    if (distance > 2.5) and (distance < 10)
      and (player:GetEnergy() > weapon:GetSecondaryEnergyCost())
-- not working !!! 
--      and GetTechTree(player:GetTeamNumber()):GetHasTech(kTechId.Leap)
      then 
        if (not player:GetIsLeaping())
          and ((player.timeOfLeap or 0) + kLeapTime < now) then
            move.commands = AddMoveCommand(move.commands, Move.SecondaryAttack)
        end
    end
    -- good for bite 
    if (distance < 2.5) then
      if (not weapon.primaryAttacking) then
        if not isBite then
          move.commands = AddMoveCommand(move.commands, Move.Weapon1)
        else
          if targetIsMoveable then
               -- Attacking a player
              targetPoint = targetPoint + Vector(math.random(), math.random(), math.random()) * 0.3
              if player:GetIsOnGround() then
                move.commands = AddMoveCommand(move.commands, Move.Jump)
              end
          else
              -- Attacking a structure
              if GetDistanceToTouch(eyePos, bestTarget) < 1 then
                  -- Stop running at the structure when close enough
                  motion:SetDesiredMoveTarget(nil)
              end
          end
        end
        move.commands = AddMoveCommand( move.commands, Move.PrimaryAttack )
      end
    -- good for parasite
    elseif 
      (not player.isHallucination)
      and (distance < 100) 
      and (Shared.GetTime() > brain.nextAttackTime) 
      and (player:GetEnergy() > weapon:GetSecondaryEnergyCost() + weapon:GetEnergyCost()) -- 30 for parasite, 45 - save for leap 
      and GetBotCanSeeTarget(player, bestTarget) then
        if (not weapon.primaryAttacking) then
          if not isParasite then
            move.commands = AddMoveCommand(move.commands, Move.Weapon2)
          else
            if bot.aim:UpdateAim(bestTarget, marinePos) then
              move.commands = AddMoveCommand(move.commands, Move.PrimaryAttack)
            else
              bot:GetMotion():SetDesiredViewTarget( nil )
            end
          end
        end   
    -- other cases     
    else
        targetPoint = nil
--        motion:SetDesiredViewTarget(nil)

        -- Occasionally jump
        if math.random() < 0.1 and (player:GetIsOnGround() or player.wallWalking) then
            move.commands = AddMoveCommand(move.commands, Move.Jump)
            if distance < 15 then
                -- When approaching, try to jump sideways
                player.timeOfJump = Shared.GetTime()
                player.jumpOffset = nil
            end    
        end        
    end
    motion:SetDesiredViewTarget(targetPoint)
    
    if player.timeOfJump ~= nil and Shared.GetTime() - player.timeOfJump < 0.5 then
        
        if player.jumpOffset == nil then
            
            local botToTarget = GetNormalizedVectorXZ(marinePos - eyePos)
            local sideVector = botToTarget:CrossProduct(Vector(0, 1, 0))                
            if math.random() < 0.5 then
                player.jumpOffset = botToTarget + sideVector
            else
                player.jumpOffset = botToTarget - sideVector
            end            
            motion:SetDesiredViewTarget( bestTarget:GetEngagementPoint() )
            
        end
        
        motion:SetDesiredMoveDirection( player.jumpOffset )
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
kSkulkBrainActions =
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
        local now = Shared.GetTime()        
        local pendingUpgrades = {}
        local player = bot:GetPlayer()
        local pendingLifeform
        
        if (player:GetIsAllowedToBuy())
        and ((bot.nextCheckEvolveTime == nil) or (bot.nextCheckEvolveTime > now)) then
            Print("CHECK")
          bot.nextCheckEvolveTime = now + 3
          
          if not player.desiredLifeform then
            local pick = math.random(1, #kEvolutions)
            player.desiredLifeform = kEvolutions[pick]
              PrintToChat(player, false, "DESIRED LIFEFORM: "..TechIdToString(player.desiredLifeform))
          end
  
  --        local ginfo = GetGameInfoEntity()
  --        if ginfo and ginfo:GetWarmUpActive() then allowedToBuy = false end
  
          local s = brain:GetSenses()

          local distanceToNearestThreat = s:Get("nearestThreat").distance
          
          local hive = s:Get("nearestHive")
          local hiveDist = hive and player:GetOrigin():GetDistance(hive:GetOrigin()) or 0
  
          if (distanceToNearestThreat == nil or distanceToNearestThreat > 30)
             and (not EntityIsVisible(player)) 
             and (player.GetIsInCombat == nil or not player:GetIsInCombat())
             and (hiveDist < 20) then
              
              -- Safe enough to try to evolve            
              
              local res = player:GetPersonalResources()
              
              local existingUpgrades = player:GetUpgrades()
  
              pendingLifeform = kTechId.Skulk
              local desiredLifeform = player.desiredLifeform
              local pendingEvolveToLifeform = false
              
              if LookupTechData(desiredLifeform, kTechDataGestateName) then
                 local cost = GetCostForTech(desiredLifeform)  
                 if res >= cost then
                    res = res - cost
                    table.insert(pendingUpgrades, desiredLifeform)
                    pendingLifeform = desiredLifeform
                    pendingEvolveToLifeform = true
                    -- force choice upgrades for desired lifeform
                    -- Print("force choice upgrades for desired lifeform")
                    -- player.desiredUpgrades = GetAlienRandomUpgrades()
                 end                              
              end
              
              if not player.desiredUpgrades then
--                Print("create desired upgrades for player"..player)
                player.desiredUpgrades = GetAlienRandomUpgrades(nil)
                  PrintToChat(player, false, "DESIRED UPGRADES: "..UpgradesToString(player.desiredUpgrades))
              end

              local techTree = player:GetTechTree()
              for _, desiredUpgradeTechId in ipairs(player.desiredUpgrades) do
                -- Print("Has Upgrade "..TechIdToString(desiredUpgradeTechId).." = "..BoolToStr(player:GetHasUpgrade(desiredUpgradeTechId)))
                if pendingEvolveToLifeform or (not player:GetHasUpgrade(desiredUpgradeTechId)) then
                  local desiredUpgradeTechNode = techTree:GetTechNode(desiredUpgradeTechId)
                  if desiredUpgradeTechNode ~= nil then
                      local isAvailable = desiredUpgradeTechNode:GetAvailable()
                      if isAvailable then
                         local cost = LookupTechData(desiredUpgradeTechId, kTechDataUpgradeCost, 0)
                         if res >= cost then
                            res = res - cost
                            table.insert(pendingUpgrades, desiredUpgradeTechId)
                         end
                      end
                  end
                end
              end
  
            end
            if #pendingUpgrades > 0 then
                weight = 100.0
            end
        end
        return { name = name, weight = weight,
            perform = function(move)
                if pendingLifeform == kTechId.Gorge then
                  -- DebugPrint("is gorge")
                  local team = player:GetTeam()
                  local teamNumber = player:GetTeamNumber()
                  local humanNum, botsNum = GetPlayerNumbersForTeam(teamNumber)
                  local teamCount = humanNum + botsNum
                  local maxGorgeCount = math.floor(teamCount / 4)
                  local gorgeCount = 0
                  local function count(player)
                    if player:isa("Gorge") or player:isa("GorgeEgg") or player:isa("Embryo") then
                      gorgeCount = gorgeCount + 1
                    end
                  end
                  team:ForEachPlayer(count)
                  -- DebugPrint("max gorge count = %d", maxGorgeCount)
                  --DebugPrint("gorgeCount = %d", gorgeCount)
                  if (gorgeCount >= maxGorgeCount) then
                    DebugPrint("Gorge evolution cancelled")
                    pendingLifeform = nil
                    pendingUpgrades = {}
                  end
                end

                if (#pendingUpgrades > 0) then
                  -- DebugPrint("%s - PROCESS BUY ACTION", EntityToString(player))
                  --PrintUpgrades(pendingUpgrades)
                  PrintToChat(player, false, string.format("%s - PROCESS BUY ACTION %s", EntityToString(player), UpgradesToString(pendingUpgrades)))
                  player:ProcessBuyAction(pendingUpgrades)
                end
                return
            end }
    end,

    --[[
    --Save hives under attack
     ]]
    function(bot, brain)
        local skulk = bot:GetPlayer()
        local teamNumber = skulk:GetTeamNumber()

        local hiveUnderAttack
        bot.hiveprotector = bot.hiveprotector or math.random()
        if bot.hiveprotector > 0.5 then
            for _, hive in ipairs(GetEntitiesForTeam("Hive", teamNumber)) do
                if hive:GetHealthScalar() <= 0.4 then
                    hiveUnderAttack = hive
                    break
                end
            end
        end

        local weight = hiveUnderAttack and 1.1 or 0
        local name = "hiveunderattack"

        return { name = name, weight = weight,
            perform = function(move)
                bot:GetMotion():SetDesiredMoveTarget(hiveUnderAttack and hiveUnderAttack:GetOrigin())
                bot:GetMotion():SetDesiredViewTarget(nil)
            end }

    end,

    ------------------------------------------
    --  
    ------------------------------------------
    function(bot, brain)
        local name = "attack"
        local skulk = bot:GetPlayer()
        local eyePos = skulk:GetEyePos()
        
        local memories = GetTeamMemories(skulk:GetTeamNumber())
        local bestUrgency, bestMem = GetMaxTableEntry( memories, 
                function( mem )
                    return GetAttackUrgency( bot, mem )
                end)
        
        local weapon = skulk:GetActiveWeapon()
        local canAttack = weapon ~= nil -- and weapon:isa("BiteLeap")

        local weight = 0.0

        if canAttack and bestMem ~= nil then

            local dist = 0.0
            if Shared.GetEntity(bestMem.entId) ~= nil then
                dist = GetDistanceToTouch( eyePos, Shared.GetEntity(bestMem.entId) )
            else
                dist = eyePos:GetDistance( bestMem.lastSeenPos )
            end

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
        
        local skulk = bot:GetPlayer()
        local eyePos = skulk:GetEyePos()

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

        local skulk = bot:GetPlayer()
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

                        PerformAttackEntity( skulk:GetEyePos(), target, bot, brain, move )
                        
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

}

------------------------------------------
--  
------------------------------------------
function CreateSkulkBrainSenses()

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

    s:Add("nearestHive", function(db)
        local player = db.bot:GetPlayer()
        local playerPos = player:GetOrigin()

        local hives = GetEntitiesForTeam("Hive", player:GetTeamNumber())

        local builtHives = {}

        -- retreat only to built hives
        for _, hive in ipairs(hives) do

            if hive:GetIsBuilt() and hive:GetIsAlive() then
                table.insert(builtHives, hive)
            end

        end

        Shared.SortEntitiesByDistance(playerPos, builtHives)

        return builtHives[1]
      end)
        
    return s
end
