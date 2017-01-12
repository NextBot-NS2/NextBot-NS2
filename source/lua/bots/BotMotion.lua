-- ======= Copyright (c) 2003-2013, Unknown Worlds Entertainment, Inc. All rights reserved. =======
--
-- Created by Steven An (steve@unknownworlds.com)
--
-- This class takes high-level motion-intents as input (ie. "I want to move here" or "I want to go in this direction")
-- and translates them into controller-inputs, ie. mouse direction and button presses.
--
-- ==============================================================================================

kDefaultPathPointHeight = 0.7

function DebugDrawPath(pathPoints, startIndex, maxCount, r, g, b, a)
  local maxPointIndex = math.min(maxCount, #pathPoints)
  local step = math.ceil(EvalLPF(maxCount, {{1, 1}, {10, 1}, {100, 10}, {1000, 30}, {10000, 100}}))
  if maxCount > 1 then
    local prevPoint = pathPoints[1]
    for i = startIndex + 1, maxPointIndex, step do
      local point = pathPoints[i]
      DebugLine(prevPoint, point, 0.2, r, g, b, a)
      prevPoint = point
    end
  end
end

-- ПРОФИЛИРОВАТЬ

local function GetNearestStraightPointForGround(fromPlayer, addHeight, desiredHeight, pathPoints, maxPointCount, minimumStepLength, maxLength)
  local result
  local length = 0
  local stepRemaining = 0
  local aimHeight = desiredHeight - kDefaultPathPointHeight
--  Print("maxPointsCount = "..maxPointCount)
  if maxPointCount > 1 then
    local fromPosition = fromPlayer:GetOrigin()
    -- нельзя local groundPos = GetGroundAt(fromEntity, fromPosition, PhysicsMask.All)
    fromPosition.y = fromPosition.y + addHeight
--    DebugLine(fromPosition, Vector(fromPosition.x, fromPosition.y + 1, fromPosition.z), 1, 1, 0.5, 0.5, 1)
    if maxPointCount == 2 then
      local point = pathPoints[2]
      result = Vector(point.x, point.y + aimHeight, point.z) 
    else
      local prevPoint = pathPoints[1]
      prevPoint = nil
      local prevReachablePoint = nil
      local prevReachablePointIndex = nil
      for i = 2, maxPointCount do
        local point = pathPoints[i]
        point = Vector(point.x, point.y + aimHeight, point.z)
--        point = Vector(point.x, point.y, point.z)
        if prevPoint ~= nil then
          local prevPointDistance = point:GetDistance(prevPoint)
          length = length + prevPointDistance
--          Print("length = "..length)
          if length > maxLength then
--            Print("maximum length reached")
            break
          end
          stepRemaining = stepRemaining - prevPointDistance
        end
--        Print("stepRemaining = "..stepRemaining)
        if stepRemaining <= 0 then
          stepRemaining = minimumStepLength
--          DebugLine(fromPosition, point, 1, 0.5, 1, 0.5, 1)
          local canMove = PlayerCanDirectMove(fromPlayer, fromPosition, point)
--          Print("canMove = "..(canMove and "true" or "false"))
          if canMove then
            prevReachablePoint = point
            prevReachablePointIndex = i
          else
--            Print("INDEX = "..(prevReachablePointIndex and prevReachablePointIndex or "nil"))
            break
          end
        end
        prevPoint = point
      end
      result = prevReachablePoint
    end
  end
  return result
end

local function GetNearestPointForGround(fromPlayer, pathPoints, maxPointCount)
  if maxPointCount > 1 then
    return pathPoints[1]
  else
    return nil
  end
end

------------------------------------------
--  Expensive pathing call
------------------------------------------
local function GetOptimalMovePosition(player, to, addHeight, desiredHeight, maxStraightLength)

    local pathPoints = PointArray()
    
    local from = player:GetOrigin()
    local reachable = Pathing.GetPathPoints(from, to, pathPoints)
    local pathPointsCount = #pathPoints
  
    if reachable and pathPointsCount > 0 then
        local prevPoint = pathPoints[1]
--        for i = 2, math.min(30, pathPointsCount) do
--          local point = pathPoints[i]
--          local point = Vector(point.x, point.y - kDefaultPathPointHeight, point.z)
--          local meshPoint = Pathing.GetClosestPoint(point)
--          Print("diff = "..(point.y - meshPoint.y))
--          DebugLine(prevPoint, point, 1, 0.2, 0.2, 0.8, 1)
--          prevPoint = point
--        end

        local aimHeight = desiredHeight - kDefaultPathPointHeight
        
--        DebugDrawPath(pathPoints, 1, pathPointsCount, 0, 0, 1, 1)
        local nearestReachablePoint
        if player:isa("Lerk") then
          local fromPosition = player:GetOrigin()
          nearestReachablePoint = BinaryDownSearch(pathPoints, pathPointsCount, 
            function(pathPoint)
              if fromPosition:GetDistance(pathPoint) > 20 then
                return false
              else
                local a2 = Vector(pathPoint.x, pathPoint.y + aimHeight, pathPoint.z)
--                DebugLine(fromPosition, a2, 0.5, 1, 1, 0.5, 0.5)
                return PlayerCanDirectMove(player, fromPosition, a2)
              end
            end
          )
          if nearestReachablePoint ~= nil then
            nearestReachablePoint.y = nearestReachablePoint.y + aimHeight
          end
        else
--          nearestReachablePoint = GetNearestStraightPointForGround(
--            player,           -- fromPlayer
--            addHeight,        -- addHeight
--            desiredHeight,    -- desiredHeight
--            pathPoints,       -- pathPoints 
--            pathPointsCount,  -- maxPointCount
--            0.4,              -- minimumStepLength
--            maxStraightLength -- maxLength
--          )
          nearestReachablePoint = GetNearestPointForGround(player, pathPoints, pathPointsCount)
        end 
        if (nearestReachablePoint == nil) then
--          Print("nearest moveable are nil")
          local point = pathPoints[1]
          nearestReachablePoint = Vector(point.x, point.y + aimHeight, point.z)
        end
        return nearestReachablePoint
    else
        -- sensible fallback
        -- DebugPrint("Could not find path from %s to %s", ToString(from), ToString(to))
--        Print(string.format("Could not find path from %s to %s", ToString(from), ToString(to)))
        return to
    end    

end

------------------------------------------
--  Provides an interface for higher level logic to specify desired motion.
--  The actual bot classes use this to compute move.move, move.yaw/pitch. Also, jump.
------------------------------------------

class "BotMotion"

Script.Load("lua/bots/oscillo.lua")

function BotMotion:Initialize(player)

    self.currMoveDir = Vector(0,0,0)
    self.currViewDir = Vector(1,0,0)
    self.lastMovedPos = player:GetOrigin()
    self.lastMovedTime = Shared.GetTime()
    self.speedHistory = Oscillo()
    self.speedHistory:Initialize(20, 0.1)
    self.desiredHeight = 1
    self.addHeight = 0.25
    self.maxStraightLength = 4
    self.desiredMoveUpdatePeriod = 0.7
    self.player = player
end

function BotMotion:ComputeLongTermTarget(player)

    local kTargetOffset = 1

    if self.desiredMoveDirection ~= nil then

        local toPoint = player:GetOrigin() + self.desiredMoveDirection * kTargetOffset
        return toPoint

    elseif self.desiredMoveTarget ~= nil then

        return self.desiredMoveTarget

    else
    
        return nil

    end    
end

------------------------------------------
--
------------------------------------------
function BotMotion:OnGenerateMove(player)
    PROFILE("NBotMotion:OnGenerateMove")
    local currentPos = player:GetOrigin()
    local eyePos = player:GetEyePos()    
    local doJump = false
    local isLerk = player:isa("Lerk")
    local now = Shared.GetTime()
    self.now = now

    local distance = currentPos:GetDistance(self.lastMovedPos)
    local dt = now - self.lastMovedTime
    self.velocity = distance / dt
--    Print("velocity = "..self.velocity)
    self.speedHistory:PutValue(self.velocity, now)
        
    --    local meshPos = Pathing.GetClosestPoint(currentPos)
--    local currentPos2 = Vector(currentPos.x, currentPos.y + 0.5, currentPos.z)
--    local meshPos2 = Vector(meshPos.x, meshPos.y + 0.5, meshPos.z)
--    local point2 = Vector(
--      (currentPos2.x + meshPos2.x) / 2 + 0.5,
--      (currentPos2.y + meshPos2.y) / 2,
--      (currentPos2.z + meshPos2.z) / 2
--    )
--    DebugLine(currentPos2, meshPos2, 5, 1, 0.5, 0.5, 1)
--    DebugLine(currentPos2, point2, 5, 0, 1, 0.5, 1)
--    DebugLine(point2, meshPos2, 5, 0.5, 0.5, 1, 1)
--    Print("difference = "..(currentPos.y - meshPos.y))


    ------------------------------------------
    --  Update ground motion
    ------------------------------------------

    local moveTargetPos = self:ComputeLongTermTarget(player)
    if moveTargetPos ~= nil and not player:isa("Embryo") then
        local distToTarget = currentPos:GetDistance(moveTargetPos)
        if distToTarget <= 0.01 then
            -- Basically arrived, stay here
            self.currMoveDir = Vector(0,0,0)
            self.currMovePos = nil
        else
            -- Path to the target position
            -- But for perf and for hysteresis control, only change direction about every 10th of a second
            local updateMoveDir = (self.nextUpdateMoveTime == nil) or (now > self.nextUpdateMoveTime)
            if isLerk and updateMoveDir and (self.currentMovePos ~= nil) then
              local dist = currentPos:GetDistance(self.currentMovePos)
              if self.currMovePosDistance ~= nil then
                updateMoveDir = dist > self.currMovePosDistance  
              end
              self.currMovePosDistance = dist
              updateMoveDir = updateMoveDir or (dist < 3) or (now > self.nextUpdateMoveTime + 2)
            end
            if updateMoveDir then
                self.nextUpdateMoveTime = now + (math.random() * self.desiredMoveUpdatePeriod) + (self.desiredMoveUpdatePeriod * 0.3)
                local directMove = false
                updateMoveDir = false
                -- If we have not actually moved much since last frame, then maybe pathing is failing us
                -- So for now, move in a random direction for a bit and jump
                if self.speedHistory:GetAvg(0, 5, nil, 999) < 2 then
                    --Print("stuck! spazzing out")
                    self.currMoveDir = GetRandomDirXZ()
                    if not isLerk then
                        doJump = true
                    else
                        self.currMoveDir.y = -2
                    end
                    self.currMovePos = nil                    
                elseif (distToTarget <= 2.0) then 
                  if (self.desiredMoveTargetEntity == nil) then
                    local fromPos = Vector(currentPos.x, currentPos.y + self.addHeight, currentPos.z)
                    local toPosOnMesh = Pathing.GetClosestPoint(moveTargetPos)
                    toPosOnMesh.y = toPosOnMesh.y + self.desiredHeight
                    if PlayerCanDirectMove(player, fromPos, toPosOnMesh) then
                      directMove = true
                    else
                      updateMoveDir = true
                    end
                  elseif GetBotCanSeeTarget(player, self.desiredMoveTargetEntity) then
                    -- Optimization: If we are close enough to target, just shoot straight for it.
                    -- We assume that things like lava pits will be reasonably large so this shortcut will
                    -- not cause bots to fall in
                    -- NOTE NOTE STEVETEMP TODO: We should add a visiblity check here. Otherwise, units will try to go through walls
                    directMove = true
                  else
                    updateMoveDir = true
                  end
                else
                    -- We are pretty far - do the expensive pathing call
                    updateMoveDir = true
                end
                
                if updateMoveDir then
                  self.currMovePos = GetOptimalMovePosition(player, moveTargetPos, self.addHeight, self.desiredHeight, self.maxStraightLength)
                  self.currMoveDir = (self.currMovePos - currentPos):GetUnit()
                elseif directMove then
                  self.currMovePos = moveTargetPos
                  self.currMoveDir = (moveTargetPos - currentPos):GetUnit()
                end
                if isLerk then
                  self.currMoveDir.y = math.min(0.1, self.currMoveDir.y) 
                  self.currMoveDir.y = math.max(-0.1, self.currMoveDir.y)
                  self.currMoveDir = self.currMoveDir:GetUnit()
                end
            end
            if isLerk then
              doJump = self:GetJumpDownedForFlaps(player)
--            elseif player:isa("skulk") then
-- прыжки должны быть в тему
--              doJump = (now > self.timeOfJump + 0.5) and (player:GetEnergyFraction() > 0.05) and (player:GetIsOnGround())
            end
        end
    else
        -- Did not want to move anywhere - stay still
        self.currMoveDir = Vector(0,0,0)
    end
    
    self.lastMovedPos = currentPos
    self.lastMovedTime = now    

    ------------------------------------------
    --  View direction
    ------------------------------------------

    if self.desiredViewTarget ~= nil then

        -- Look at target
        self.currViewDir = (self.desiredViewTarget - eyePos):GetUnit()

    elseif self.currMoveDir:GetLength() > 1e-4 then

        -- Look in move dir
        self.currViewDir = self.currMoveDir
        if player:isa("Lerk") then
        else
          self.currViewDir.y = 0.0  -- pathing points are slightly above ground, which leads to funny looking-up
        end
        self.currViewDir = self.currViewDir:GetUnit()

    else
        -- leave it alone
    end

    return self.currViewDir, self.currMoveDir, doJump

end


function BotMotion:GetJumpDownedForFlaps(player)
  local doJump = false
  local now = self.now
  if (player.accelerateFlapsCount == nil) and player:GetIsOnGround() then
    doJump = true
    player.timeOfJump = now
    player.timeOfJumpRelease = nil
    player.jumpOffset = nil
    player.accelerateFlapsCount = 3
  else
    local flapPeriod
    if player.accelerateFlapsCount and player.accelerateFlapsCount > 0 then
      flapPeriod = 0.2
    else
      player.accelerateFlapsCount = nil
      flapPeriod = EvalLPF(self.velocity, {
        {0, 0.2},
        {7, 0.3},
        {13, 3},
        {20, 4}
      })
    end
--    Print("Flap period = "..flapPeriod)
    if (player.timeOfJumpRelease ~= nil) and (now < player.timeOfJumpRelease + 0.05) then
--      PrintToChat(player, false, "hold release")
--      Print("Hold release")
      -- hold jump key released - do nothing
    elseif (player.timeOfJump == nil) then
      if player.accelerateFlapsCount then
        player.accelerateFlapsCount = player.accelerateFlapsCount - 1
      end
--      Print(player, false, "down jump")
--      Print("down jump")
      -- down the jump key
      doJump = true
      player.timeOfJump = now
      player.timeOfJumpRelease = nil
    elseif (now < player.timeOfJump + flapPeriod) then
--      PrintToChat(player, false, "hold jump"..player.timeOfJump.." : "..now)
--      Print("hold jump")
      -- hold the jump key
      doJump = true
    else
--      PrintToChat(player, false, "release jump")
--      Print("release jump")
      -- release the jump key
      player.timeOfJump = nil
      player.timeOfJumpRelease = now
    end
  end
  return doJump
end


------------------------------------------
--  Higher-level logic interface
------------------------------------------
function BotMotion:SetDesiredMoveTarget(toPoint)

    -- Mutually exclusive
    self:SetDesiredMoveDirection(nil)

    if not VectorsApproxEqual( toPoint, self.desiredMoveTarget, 1e-4 ) then
      self.desiredMoveTarget = toPoint
      self.desiredMoveEntity = nil
    end
end

function BotMotion:SetDesiredMoveTargetEntity(entity)
    local toPoint = entity:GetEngagementPoint()
    self:SetDesiredMoveTarget(toPoint)
    self.desiredMoveEntity = entity
end

------------------------------------------
--  Higher-level logic interface
------------------------------------------
-- Note: while a move direction is set, it overrides a target set by SetDesiredMoveTarget
function BotMotion:SetDesiredMoveDirection(direction)

    if not VectorsApproxEqual( direction, self.desiredMoveDirection, 1e-4 ) then
        self.desiredMoveDirection = direction
    end
    
end

------------------------------------------
--  Higher-level logic interface
--  Set to nil to clear view target
------------------------------------------
function BotMotion:SetDesiredViewTarget(target)

    self.desiredViewTarget = target

end

