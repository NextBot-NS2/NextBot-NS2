
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
local function GetAttackUrgency(bot, mem)

    -- See if we know whether if it is alive or not
    local ent = Shared.GetEntity(mem.entId)
    if not HasMixin(ent, "Live") or not ent:GetIsAlive() then
        return 0.0
    end

    local botPos = bot:GetPlayer():GetOrigin()
    local targetPos = ent:GetOrigin()
    local distance = botPos:GetDistance(targetPos)

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
        [kMinimapBlipType.Marine] =             numOthers >= 2 and 0.6 or 1,
        [kMinimapBlipType.JetpackMarine] =      numOthers >= 2 and 0.7 or 1.1,
        [kMinimapBlipType.Exo] =                numOthers >= 2 and 0.8 or 1.2,

        [kMinimapBlipType.ARC] =                numOthers >= 1 and 0.4 or 0.9,
        [kMinimapBlipType.CommandStation] =     numOthers >= 2 and 0.3 or 0.75,
        [kMinimapBlipType.PhaseGate] =          numOthers >= 1 and 0.2 or 0.9,
        [kMinimapBlipType.Observatory] =        numOthers >= 1 and 0.2 or 0.8,
        [kMinimapBlipType.Extractor] =          numOthers >= 1 and 0.2 or 0.7,
        [kMinimapBlipType.InfantryPortal] =     numOthers >= 1 and 0.2 or 0.6,
    }

    if urgencies[ mem.btype ] ~= nil then
        return urgencies[ mem.btype ]
    end

    return 0.0

end


local function PerformAttackEntity( eyePos, bestTarget, bot, brain, move )

    assert( bestTarget )

    local player = bot:GetPlayer()
    local marinePos = bestTarget:GetOrigin()

    local doFire = false
    bot:GetMotion():SetDesiredMoveTarget( marinePos )
    
    local distance = eyePos:GetDistance(marinePos)
    if distance < 2.5 then
        doFire = true
    end
                
    if doFire then
        -- jitter view target a little bit
        -- local jitter = Vector( math.random(), math.random(), math.random() ) * 0.1
        bot:GetMotion():SetDesiredViewTarget( bestTarget:GetEngagementPoint() )
        move.commands = AddMoveCommand( move.commands, Move.PrimaryAttack )
        
        if bestTarget:isa("Player") then
            -- Attacking a player
            if player:GetIsOnGround() and bestTarget:isa("Player") then
                move.commands = AddMoveCommand( move.commands, Move.SecondaryAttack )
            end
        else
            -- Attacking a structure
            if GetDistanceToTouch(eyePos, bestTarget) < 1 then
                -- Stop running at the structure when close enough
                bot:GetMotion():SetDesiredMoveTarget(nil)
            end
        end   
    else
        bot:GetMotion():SetDesiredViewTarget( nil )

        -- Occasionally jump
        if math.random() < 0.1 and bot:GetPlayer():GetIsOnGround() then
            move.commands = AddMoveCommand( move.commands, Move.SecondaryAttack )
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
kFadeBrainActions =
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
    
                if math.random() < 0.1 and bot:GetPlayer():GetIsOnGround() then
                    move.commands = AddMoveCommand( move.commands, Move.SecondaryAttack )
                    move.commands = AddMoveCommand( move.commands, Move.Jump )   
                end
    
                bot:GetMotion():SetDesiredMoveTarget(targetPos)
                bot:GetMotion():SetDesiredViewTarget(nil)
                
                end ),
    
    ------------------------------------------
    --
    ------------------------------------------
    CreateEvolveAction(),
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
        local canAttack = weapon ~= nil and weapon:isa("SwipeBlink")

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
                                        
                        if math.random() < 0.1 and bot:GetPlayer():GetIsOnGround() then
                            move.commands = AddMoveCommand( move.commands, Move.SecondaryAttack )
                            move.commands = AddMoveCommand( move.commands, Move.Jump )   
                        end

                    end
                end
            end }
    end,

    function(bot, brain)
        local weight = 0
        local player = bot:GetPlayer()

        if player:GetVelocity():GetLength() < 8 and player:GetEnergy() > 60 then
            weight = 26
        end

        return { name = "bink", weight = weight,
            perform = function(move)
                move.commands = AddMoveCommand( move.commands, Move.SecondaryAttack )
            end }
    end,

    function(bot, brain)
        local weight = 0
        local player = bot:GetPlayer()

        if player:GetEnergy() < 30 and (bot.timeOfMeta or 0) < Shared.GetTime() then
            weight = 26
            bot.timeOfMeta = Shared.GetTime() + kMetabolizeDelay
        end

        return { name = "meta", weight = weight,
            perform = function(move)
                move.commands = AddMoveCommand( move.commands, Move.MovementModifier )
            end }
    end,

    function(bot, brain)

        local name = "retreat"
        local player = bot:GetPlayer()
        local sdb = brain:GetSenses()

        local hive = sdb:Get("nearestHive")
        local hiveDist = hive and player:GetOrigin():GetDistance(hive:GetOrigin()) or 0
        local healthFraction = sdb:Get("healthFraction")

        local weight = 0.0
  
        if (not EntityIsVisible(player)) and (hiveDist < 4) and (healthFraction < 0.9) then
          -- standing for full repair
          weight = 25.0
        else
          -- If we are pretty close to the hive, stay with it a bit longer to encourage full-healing, etc.
          -- so pretend our situation is more dire than it is
          if hiveDist < 4.0 and healthFraction < 0.9 then
              healthFraction = healthFraction / 3.0
          end
  
          if hive then
  
              weight = EvalLPF( healthFraction, {
                  { 0.0, 25.0 },
                  { 0.6, 0.0 },
                  { 1.0, 0.0 }
              })
          end
        end

        return { name = name, weight = weight,
            perform = function(move)
                if hive then

                    -- we are retreating, unassign ourselves from anything else, e.g. attack targets
                    brain.teamBrain:UnassignBotFromAll(bot)

                    local touchDist = GetDistanceToTouch( player:GetEyePos(), hive )
                    if touchDist > 1.5 then
                        bot:GetMotion():SetDesiredMoveTarget( hive:GetEngagementPoint() )
                        bot:GetMotion():SetDesiredViewTarget( nil )
                    else
                        -- sit and wait to heal
                        bot:GetMotion():SetDesiredViewTarget( hive:GetEngagementPoint() )
                        bot:GetMotion():SetDesiredMoveTarget( nil )
                    end
                end

            end }

    end,

}

------------------------------------------
--
------------------------------------------
function CreateFadeBrainSenses()

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

    s:Add("healthFraction", function(db)
        local player = db.bot:GetPlayer()
        return player:GetHealthFraction()
    end)

    return s
end
