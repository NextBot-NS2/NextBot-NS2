------------------------------------------
-- Collection of common actions shared between many brains
------------------------------------------

Script.Load("lua/bots/BotUtils.lua")

function CreateExploreAction(weightIfTargetAcquired, moveToFunction)
	
	return function(bot, brain)
		
		local name = "explore"
		local player = bot:GetPlayer()
		local origin = player:GetOrigin()
		
		local findNew = true
		if brain.exploreTargetId ~= nil then
			local target = Shared.GetEntity(brain.exploreTargetId)
			if target ~= nil then
				local dist = target:GetOrigin():GetDistance(origin)
				if dist > 5.0 then
					findNew = false
				end
			end
		end
		
		if findNew then
			
			local memories = GetTeamMemories(player:GetTeamNumber())
			local exploreMems = FilterTable(memories,
				function(mem)
					return mem.entId ~= brain.exploreTargetId
							and (mem.btype == kMinimapBlipType.ResourcePoint
							or mem.btype == kMinimapBlipType.TechPoint)
				end)
			
			-- pick one randomly
			if #exploreMems > 0 then
				local targetMem = exploreMems[math.random(#exploreMems)]
				brain.exploreTargetId = targetMem.entId
			else
				brain.exploreTargetId = nil
			end
		end
		
		local weight = 0.0
		if brain.exploreTargetId ~= nil then
			weight = weightIfTargetAcquired
		end
		
		return {
			name = name,
			weight = weight,
			perform = function(move)
				local target = Shared.GetEntity(brain.exploreTargetId)
				if brain.debug then
					DebugPrint("exploring to move target %s", ToString(target:GetOrigin()))
				end
				
				moveToFunction(origin, target:GetOrigin(), bot, brain, move)
			end
		}
	end
end


------------------------------------------
-- Commander stuff
------------------------------------------
function CreateBuildStructureAction(techId, className, numExistingToWeightLPF, buildNearClass, maxDist)
	
	return function(bot, brain)
		
		local name = "build" .. EnumToString(kTechId, techId)
		local com = bot:GetPlayer()
		local sdb = brain:GetSenses()
		local doables = sdb:Get("doableTechIds")
		local weight = 0.0
		local coms = doables[techId]
		
		-- find structures we can build near
		local hosts = GetEntitiesForTeam(buildNearClass, com:GetTeamNumber())
		
		if coms ~= nil and #coms > 0
				and hosts ~= nil and #hosts > 0 then
			assert(coms[1] == com)
			
			-- figure out how many exist already
			local existingEnts = GetEntitiesForTeam(className, com:GetTeamNumber())
			weight = EvalLPF(#existingEnts, numExistingToWeightLPF)
		end
		
		return {
			name = name,
			weight = weight,
			perform = function(move)
				
				-- Pick a random host for now
				local host = hosts[math.random(#hosts)]
				local pos = GetRandomBuildPosition(techId, host:GetOrigin(), maxDist)
				if pos ~= nil then
					brain:ExecuteTechId(com, techId, pos, com)
				end
			end
		}
	end
end

function CreateUpgradeStructureAction(techId, weightIfCanDo, existingTechId)
	
	return function(bot, brain)
		
		local name = EnumToString(kTechId, techId)
		local com = bot:GetPlayer()
		local sdb = brain:GetSenses()
		local doables = sdb:Get("doableTechIds")
		local weight = 0.0
		local structures = doables[techId]
		
		if structures ~= nil then
			
			weight = weightIfCanDo
			
			-- but if we have the upgrade already, halve the weight
			-- TODO THIS DOES NOT WORK WTFFF
			if existingTechId ~= nil then
				--                DebugPrint("Checking if %s exists..", EnumToString(kTechId, existingTechId))
				if GetTechTree(com:GetTeamNumber()):GetHasTech(existingTechId) then
					DebugPrint("halving weight for already having %s", name)
					weight = weight * 0.5
				end
			end
		end
		
		return {
			name = name,
			weight = weight,
			perform = function(move)
				
				if structures == nil then return end
				-- choose a random host
				local host = structures[math.random(#structures)]
				brain:ExecuteTechId(com, techId, Vector(0, 0, 0), host)
			end
		}
	end
end

function CreateEvolveAction()
	return function(bot, brain)
		local name = "evolve"
		
		local weight = 0.0
		local now = Shared.GetTime()
		local pendingUpgrades = {}
		local player = bot:GetPlayer()
		local pendingLifeform
		local existingUpgrades = player:GetUpgrades()
		
		if not player.desiredUpgrades then
			--                Print("create desired upgrades for player"..player)
			player.desiredUpgrades = GetAlienRandomUpgrades(existingUpgrades)
--			PrintToChat(player, false, "DESIRED UPGRADES: " .. UpgradesToString(player.desiredUpgrades))
		end
		
--		Print(string.format("desired: %d, existing: %d, allowed: %s", #player.desiredUpgrades, #existingUpgrades, player:GetIsAllowedToBuy()))
	
		if (#player.desiredUpgrades ~= #existingUpgrades) and (player:GetIsAllowedToBuy())
				and ((bot.nextCheckEvolveTime == nil) or (now > bot.nextCheckEvolveTime)) then
		
			bot.nextCheckEvolveTime = now + 3
			
			local s = brain:GetSenses()
			
			local distanceToNearestThreat = s:Get("nearestThreat").distance
			
			local treatTooFar = (distanceToNearestThreat == nil) or (distanceToNearestThreat > 20)
			local entitySighted = EntityIsVisible(player)
			local notInCombat = (player.GetIsInCombat == nil) or (not player:GetIsInCombat())
			Print(string.format('treatTooFar = %s, EntityIsVisible = %s, noInCombat: %s', BoolToStr(treatTooFar), BoolToStr(entitySighted), BoolToStr(notInCombat)))
			if (treatTooFar)
					and (not entitySighted)
					and (notInCombat) then
				
				-- Safe enough to try to evolve
				
				local res = player:GetPersonalResources()
				local techTree = player:GetTechTree()
				for _, desiredUpgradeTechId in ipairs(player.desiredUpgrades) do
					-- Print("Has Upgrade "..TechIdToString(desiredUpgradeTechId).." = "..BoolToStr(player:GetHasUpgrade(desiredUpgradeTechId)))
					if not player:GetHasUpgrade(desiredUpgradeTechId) then
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
		return {
			name = name,
			weight = weight,
			perform = function(move)
				if (#pendingUpgrades > 0) then
--					PrintToChat(player, false, string.format("%s - PROCESS BUY ACTION %s", EntityToString(player), UpgradesToString(pendingUpgrades)))
					player:ProcessBuyAction(pendingUpgrades)
				end
				return
			end
		}
	end
end
