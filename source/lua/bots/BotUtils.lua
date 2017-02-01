------------------------------------------
-- Collection of useful, bot-specific utility functions
------------------------------------------
function EntityIsVisible(entity)
	--  if entity:GetIsVisible() then
	--    return not HasMixin(entity, "Cloakable") or not entity:GetIsCloaked()
	--  else
	return HasMixin(entity, "LOS") and entity:GetIsSighted()
	--  end
end

function BoolToStr(bool)
	return bool and "true" or "false"
end

-- https://coronalabs.com/blog/2014/09/02/tutorial-printing-table-contents/
function PrintTable(t)
	Print(type(t))
	local print_r_cache = {}
	local function sub_print_r(t, indent)
		if (print_r_cache[tostring(t)]) then
			Print(indent .. "*" .. tostring(t))
		else
			print_r_cache[tostring(t)] = true
			if (type(t) == "table") then
				for pos, val in pairs(t) do
					if (type(val) == "table") then
						Print(indent .. "[" .. pos .. "] => " .. tostring(t) .. " {")
						sub_print_r(val, indent .. string.rep(" ", string.len(pos) + 8))
						Print(indent .. string.rep(" ", string.len(pos) + 6) .. "}")
					elseif (type(val) == "string") then
						Print(indent .. "[" .. pos .. '] => "' .. val .. '"')
					else
						Print(indent .. "[" .. pos .. "] => " .. tostring(val))
					end
				end
			else
				Print(indent .. ToString(t))
			end
		end
	end

	if (type(t) == "table") then
		Print(ToString(t) .. " {")
		sub_print_r(t, "  ")
		Print("}")
	else
		sub_print_r(t, "is not a table")
	end
	Print("")
end

------------------------------------------
--
------------------------------------------
function GetBestAimPoint(target)

	if target.GetEngagementPoint then

		return target:GetEngagementPoint()

	elseif HasMixin(target, "Model") then

		local min, max = target:GetModelExtents()
		local o = target:GetOrigin()
		return (min + max) * 0.5 + o - Vector(0, 0.2, 0)

	else

		return target:GetOrigin()
	end
end

------------------------------------------
--
------------------------------------------
function GetDistanceToTouch(from, target)

	local entSize = 0

	if HasMixin(target, "Extents") then
		entSize = target:GetExtents():GetLengthXZ()
	end

	local targetPos = target:GetOrigin()

	if HasMixin(target, "Target") then
		targetPos = target:GetEngagementPoint()
	end

	return math.max(0.0, targetPos:GetDistance(from) - entSize)
end

------------------------------------------
--
------------------------------------------
function GetNearestFiltered(from, ents, isValidFunc)

	local bestDist = nil
	local bestEnt = nil

	for i, ent in ipairs(ents) do

		if isValidFunc == nil or isValidFunc(ent) then

			local dist = GetDistanceToTouch(from, ent)
			if bestDist == nil or dist < bestDist then
				bestDist = dist
				bestEnt = ent
			end
		end
	end

	return bestDist, bestEnt
end

------------------------------------------
--
------------------------------------------
function GetMaxEnt(ents, valueFunc)

	local maxEnt = nil
	local maxValue = nil
	for i, ent in ipairs(ents) do
		local value = valueFunc(ent)
		if maxValue == nil or value > maxValue then
			maxEnt = ent
			maxValue = value
		end
	end

	return maxValue, maxEnt
end

------------------------------------------
--
------------------------------------------
function FilterTableEntries(ents, filterFunc)

	result = {}
	for key, entry in pairs(ents) do
		if filterFunc(entry) then
			table.insert(result, entry)
		end
	end

	return result
end

------------------------------------------
--
------------------------------------------
function GetMaxTableEntry(table, valueFunc)

	local maxEntry = nil
	local maxValue = nil
	for key, entry in pairs(table) do
		local value = valueFunc(entry)
		if value == nil then
			-- skip this
		elseif maxValue == nil or value > maxValue then
			maxEntry = entry
			maxValue = value
		end
	end

	return maxValue, maxEntry
end

function GetMinTableEntry(table, valueFunc)

	local minEntry = nil
	local minValue = nil
	for key, entry in pairs(table) do
		local value = valueFunc(entry)
		if value == nil then
			-- skip this
		elseif minValue == nil or value < minValue then
			minEntry = entry
			minValue = value
		end
	end

	return minValue, minEntry
end

------------------------------------------
--
------------------------------------------
function GetMinDistToEntities(fromEnt, toEnts)

	local minDist = nil
	local fromPos = fromEnt:GetOrigin()

	for _, toEnt in ipairs(toEnts) do

		local dist = toEnt:GetOrigin():GetDistance(fromPos)
		if minDist == nil or dist < minDist then
			minDist = dist
		end
	end

	return minDist
end

------------------------------------------
--
------------------------------------------
function GetMinPathDistToEntities(fromEnt, toEnts)

	local minDist
	local fromPos = fromEnt:GetOrigin()

	for _, toEnt in ipairs(toEnts) do

		local path = PointArray()
		Pathing.GetPathPoints(fromPos, toEnt:GetOrigin(), path)
		local dist = GetPointDistance(path)

		if not minDist or dist < minDist then
			minDist = dist
		end
	end

	return minDist
end


------------------------------------------
--
------------------------------------------
function FilterArray(ents, keepFunc)

	local out = {}
	for i, ent in ipairs(ents) do
		if keepFunc(ent) then
			table.insert(out, ent)
		end
	end
	return out
end

------------------------------------------
--
------------------------------------------
function GetPotentialTargetEntities(player)

	local origin = player:GetOrigin()
	local range = 40
	local teamNumber = GetEnemyTeamNumber(player:GetTeamNumber())

	local function filterFunction(entity)
		return HasMixin(entity, "Team") and HasMixin(entity, "LOS") and HasMixin(entity, "Live") and
				entity:GetTeamNumber() == teamNumber and EntityIsVisible(entity) and entity:GetIsAlive()
	end

	return Shared.GetEntitiesWithTagInRange("class:ScriptActor", origin, range, filterFunction)
end

------------------------------------------
--
------------------------------------------
function GetTeamMemories(teamNum)

	local team = GetGamerules():GetTeam(teamNum)
	assert(team)
	assert(team.brain)
	return team.brain:GetMemories()
end

------------------------------------------
--
------------------------------------------
function GetTeamBrain(teamNum)

	local team = GetGamerules():GetTeam(teamNum)
	assert(team)
	return team:GetTeamBrain()
end

------------------------------------------
--
------------------------------------------
function GetTableSize(t)
	local c = 0
	for _, _ in pairs(t) do
		c = c + 1
	end
	return c
end

------------------------------------------
-- This is expensive.
-- It would be nice to piggy back off of LOSMixin, but that is delayed and also does not remember WHO can see what.
-- -- Fixed some bad logic.  Now, we simply look to see if the trace point is further away than the target, and if so,
-- It's a hit.  Previous logic seemed to assume that if the target itself wasn't hit (caused by the EngagementPoint not
-- being inside a collision solid -- the skulk for example moves around a lot) then it magically wasn't there anymore.
------------------------------------------
function GetBotCanSeeTarget(attacker, target)

	local p0 = attacker:GetEyePos()
	local p1 = target:GetEngagementPoint()
	local bias = 0.25 -- allow trace entity to be this much closer and still call a hit

	local trace = Shared.TraceRay(p0, p1,
		CollisionRep.Damage, PhysicsMask.Bullets,
		EntityFilterTwo(attacker, attacker:GetActiveWeapon()))
	--return trace.entity == target
	return (trace.entity == target) or (((trace.endPoint - p0):GetLengthSquared()) >= ((p0 - p1):GetLengthSquared() - bias))
end

function PlayerCanDirectMove(player, from, to)
	local bias = 0.25 -- allow trace entity to be this much closer and still call a hit
	local extents = player:GetExtents()
	--    Print(string.format("extents x = %.2f, y = %.2f, z = %.2f", extents.x, extents.y, extents.z))
	local from2 = Vector(from.x, from.y + extents.y / 2, from.z)
	local to2 = Vector(to.x, to.y + extents.y / 2, to.z)
	--    DebugLine(from2, to2, 5, 1, 1, 1, 1)
	local trace = Shared.TraceCapsule(from2,
		to2,
		extents.x / 2,
		extents.y,
		CollisionRep.Move,
		PhysicsMask.Movement,
		EntityFilterTwo(player, player:GetActiveWeapon()))
	--    local trace = Shared.TraceRay(from, to,
	--            CollisionRep.Move, PhysicsMask.All,
	--            EntityFilterTwo(attacker, attacker:GetActiveWeapon()) )
	--    --return trace.entity == target
	--    Print("LENGTH = "..(trace.endPoint - from):GetLength().." fromto: ".. (from - to):GetLength())
	--    DebugLine(from2, trace.endPoint, 2, 1, 0.3, 0.3, 1)
	--    DebugLine(trace.endPoint, to2, 2, 0.3, 0.3, 0.3, 1)
	return ((trace.endPoint - from):GetLengthSquared())
			>= ((from - to):GetLengthSquared() - bias)
end

function IsAimingAt(attacker, target)

	local toTarget = GetNormalizedVector(target:GetEngagementPoint() - attacker:GetEyePos())
	return toTarget:DotProduct(attacker:GetViewCoords().zAxis) > 0.99
end

------------------------------------------
--
------------------------------------------
function FilterTable(dict, keepFunc)
	local out = {}
	for key, val in pairs(dict) do
		if keepFunc(val) then
			table.insert(out, val)
		end
	end
	return out
end

------------------------------------------
--
------------------------------------------
function GetNumEntitiesOfType(className, teamNumber)
	local ents = GetEntitiesForTeam(className, teamNumber)
	return #ents
end

------------------------------------------
--
------------------------------------------
function GetAvailableTechPoints()

	local tps = {}
	for _, tp in ientitylist(Shared.GetEntitiesWithClassname("TechPoint")) do

		if not tp:GetAttached() then
			table.insert(tps, tp)
		end
	end

	return tps
end

function GetAvailableResourcePoints()

	local rps = {}
	for _, rp in ientitylist(Shared.GetEntitiesWithClassname("ResourcePoint")) do

		if not rp:GetAttached() then
			table.insert(rps, rp)
		end
	end

	return rps
end

function GetServerContainsBots()

	local hasBots = false
	local players = Shared.GetEntitiesWithClassname("Player")
	for p = 0, players:GetSize() - 1 do

		local player = players:GetEntityAtIndex(p)
		local ownerClient = player and Server.GetOwner(player)
		if ownerClient and ownerClient:GetIsVirtual() then

			hasBots = true
			break
		end
	end

	return hasBots
end

function GetPlayerNumbersForTeam(teamNumber)

	local botNum = 0
	local humanNum = 0

	local team = GetGamerules():GetTeam(teamNumber)
	assert(team)

	local function count(player)
		local client = player:GetClient()
		if client and not client:GetIsVirtual() then
			humanNum = humanNum + 1
		end
	end

	for _, bot in ipairs(gServerBots) do
		if bot:GetTeamNumber() == teamNumber then
			botNum = botNum + 1
		end
	end

	team:ForEachPlayer(count)
	return humanNum, botNum
end

function BinaryDownSearch(data, count, queryFunc)
	-- Set the left and right boundaries
	local result = nil
	local pos = count
	repeat
		-- Get the middle value, between the left and right boundaries
		local value = data[pos]
		--      Print("Checking "..pos)
		if queryFunc(value) == true then
			result = value
			break
		else
			pos = math.floor(pos / 2)
		end
	until pos <= 1
	--    Print("binary search result = "..(pos or "nil")..", count ="..count)
	return result
	-- The query wasn't found in the array
end

function PrintToChat(player, teamOnly, message)

	if message then
		if (player.lastChatMessage == nil) or (player.lastChatMessage ~= message) then
			local chatMessage = string.sub(message, 1, kMaxChatLength)

			if chatMessage and (string.len(chatMessage) > 0) then
				local playerName = player:GetName()
				local playerLocationId = player.locationId
				local playerTeamNumber = player:GetTeamNumber()
				local playerTeamType = player:GetTeamType()

				if teamOnly then
					local players = GetEntitiesForTeam("Player", playerTeamNumber)
					for index, player in ipairs(players) do
						Server.SendNetworkMessage(player, "Chat", BuildChatMessage(true, playerName, playerLocationId, playerTeamNumber, playerTeamType, chatMessage), true)
					end
				else
					Server.SendNetworkMessage("Chat", BuildChatMessage(false, playerName, playerLocationId, playerTeamNumber, playerTeamType, chatMessage), true)
				end

				Shared.Message("Chat " .. (teamOnly and "Team - " or "All - ") .. playerName .. ": " .. chatMessage)

				-- We save a history of chat messages received on the Server.
				Server.AddChatToHistory(chatMessage, playerName, player:GetClient():GetUserId(), playerTeamNumber, teamOnly)
			end
			player.lastChatMessage = message
		end
	end
end

function TechIdToString(techId)
	return LookupTechData(techId, kTechDataDisplayName, string.format("techId=%d", techId))
end

--------------------- UPGRADES ----------------------

-- copied from AlienUI_GetUpgradesForCategory()
function GetAvailableUpgradesForHiveTypeId(hiveTypeId)
	Print("GetAvailableUpgradesForHiveTypeId " .. TechIdToString(hiveTypeId))
	local upgrades = {}
	local techTree = GetTechTree(kAlienTeamType)
	if techTree then
		for _, upgradeId in ipairs(techTree:GetAddOnsForTechId(kTechId.AllAliens)) do
			Print("test upgrade " .. TechIdToString(upgradeId) .. " >>> " .. TechIdToString(LookupTechData(upgradeId, kTechDataCategory, kTechId.None)))
			if LookupTechData(upgradeId, kTechDataCategory, kTechId.None) == hiveTypeId then
				Print("### available upgrade " .. TechIdToString(upgradeId))
				table.insert(upgrades, upgradeId)
			end
		end
	end
	Print("#upgrades = " .. #upgrades)
	return upgrades
end

function UpgradesToString(upgrades)
	local res = ''
	for i = 1, #upgrades do
		if i > 1 then
			res = res..' '
		end
		res = res..TechIdToString(upgrades[i])
	end
	return res
end

-- hive type id -> upgrade tech id
local kAlienAvailableUpgrades

function GetAlienRandomUpgrades(existingUpgrades)

	-- проверяем, есть ли список возможных апгрейдов для данного типа жизни
	-- при необходимости инициализируем

	if not kAlienAvailableUpgrades then
		kAlienAvailableUpgrades = {}

		local techTree = GetTechTree(kAlienTeamType)
		if techTree then
			for _, upgradeId in ipairs(techTree:GetAddOnsForTechId(kTechId.AllAliens)) do
--              Print("test upgrade "..TechIdToString(upgradeId).." >>> "..TechIdToString(LookupTechData(upgradeId, kTechDataCategory, kTechId.None)))
				local techCategory = LookupTechData(upgradeId, kTechDataCategory, kTechId.None)
				if (techCategory == kTechId.CragHive) or (techCategory == kTechId.ShiftHive) or (techCategory == kTechId.ShadeHive) then
					--                Print("### available upgrade "..TechIdToString(upgradeId).." for "..TechIdToString(techCategory))
					local hiveUpgrades = kAlienAvailableUpgrades[techCategory]
					if not hiveUpgrades then
						hiveUpgrades = {}
					end
					table.insert(hiveUpgrades, upgradeId)
--					Print("hive upgrades "..#hiveUpgrades)
					kAlienAvailableUpgrades[techCategory] = hiveUpgrades
				end
			end
		end
	end
	local existUpgradeHiveTypes = {}
	if existingUpgrades ~= nil then
		for _, existingUpgrade in pairs(existingUpgrades) do
			local hiveTypeForUpgrade = GetHiveTypeForUpgrade(existingUpgrade)
			-- Print("existHiveTypeForUpgrade = "..TechIdToString(hiveTypeForUpgrade))
			existUpgradeHiveTypes[hiveTypeForUpgrade] = hiveTypeForUpgrade
		end
	end
	
	--  PrintTable(kAlienAvailableUpgrades)
	local desiredUpgrades
	if existingUpgrades ~= nil then
		desiredUpgrades = existingUpgrades
	else
		desiredUpgrades = {}
	end
	
	for hiveType, possibleUpgrades in pairs(kAlienAvailableUpgrades) do
		if existUpgradeHiveTypes[hiveType] == nil then
			local upgradeCount = #possibleUpgrades
			Print("upgrade count = "..upgradeCount)
			local upgradeIndex = math.random(1, upgradeCount)
			Print("upgrade index = "..upgradeIndex)
			local desiredUpgrade = possibleUpgrades[upgradeIndex]
			Print("desiredUpgrade = "..TechIdToString(desiredUpgrade))
			table.insert(desiredUpgrades, desiredUpgrade)
		end
	end
	return desiredUpgrades
end

function BoolToStr(bool)
	return bool and "true" or "false"
end