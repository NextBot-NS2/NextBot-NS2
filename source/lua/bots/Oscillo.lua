Script.Load("lua/bots/HistoryArray.lua")

class "Oscillo"

function Oscillo:Initialize(quantumCount, quantumLength)
  self.quantumCount = quantumCount
  self.quantumLength = quantumLength
  self.quantumArray = HistoryArray()
  self.quantumArray:Initialize(quantumCount)
  self.currentQuantumStartTime = nil
  self.currentQuantumAggCount = 0
  self.currentQuantumAggSumm = 0
end

function Oscillo:PutValue(value, time)
  local dt 
  if not self.currentQuantumStartTime then
    self.currentQuantumStartTime = time
  end
  dt = time - self.currentQuantumStartTime
  if dt >= self.quantumLength then
    local lastAvg = nil
    if (self.currentQuantumAggCount > 0) then 
      lastAvg = self.currentQuantumAggSumm / self.currentQuantumAggCount
    end
    self.quantumArray:PutValue(lastAvg)
    self.currentQuantumStartTime = Shared.GetTime()
    self.currentQuantumAggCount = 1
    self.currentQuantumAggSumm = value
  else
    self.currentQuantumAggCount = self.currentQuantumAggCount + 1
    self.currentQuantumAggSumm = self.currentQuantumAggSumm + value
  end
end

-- index == 0 - current avg
function Oscillo:GetValues(fromIndex, toIndex, defaultValue)
  local result = {}
  if (fromIndex < 0) or (fromIndex >= toIndex) then
    error('invalid index')
  else
    local resultIndex = 0
    local lastAvg = nil
    if (self.currentQuantumAggCount > 0) then 
      lastAvg = self.currentQuantumAggSumm / self.currentQuantumAggCount
    end
    if fromIndex == 0 and lastAvg then
      result[resultIndex] = lastAvg
      resultIndex = resultIndex + 1
    else
      fromIndex = fromIndex - 1
      toIndex = toIndex - 1
    end
    for i = fromIndex, toIndex do
      local value = self.quantumArray:GetValueByIndex(i, defaultValue)
      result[resultIndex] = value
      resultIndex = resultIndex + 1
    end
  end
  return result
end

-- если fromIndex равен 0, то в начало списка подставляется текущее значение, еще не отправленное в историю
function Oscillo:GetAvg(fromIndex, count, defaultItemValue, defaultResultValue)
--  Print("---")
  local result = defaultResultValue
  if (fromIndex < 0) or (count <= 0) then
    error('invalid index or count')
  else
    local aggCount = 0
    local aggSumm = 0.0
    local lastAvg = nil
    if (self.currentQuantumAggCount > 0) then 
      lastAvg = self.currentQuantumAggSumm / self.currentQuantumAggCount
--      Print("LastAvg = "..lastAvg..", Count = "..self.currentQuantumAggCount..", Summ = "..self.currentQuantumAggSumm)
    end
    if fromIndex == 0 then
      if lastAvg then
--        Print(".1")
        aggCount = aggCount + 1
        aggSumm = aggSumm + lastAvg
        count = count - 1
      end
    else
      fromIndex = fromIndex - 1
    end
    if fromIndex >= 0 then
--      Print("from = "..fromIndex.." to "..fromIndex)
      for i = fromIndex, fromIndex + count - 1 do
        local value = self.quantumArray:GetValueByIndex(i, defaultItemValue)
        if value then
          aggCount = aggCount + 1
          aggSumm = aggSumm + value
        end
      end
    end
    if aggCount > 0 then
      result = aggSumm / aggCount
    end
--    Print("aggCount = "..aggCount..", aggSumm = "..aggSumm)
  end
  if result then
--    Print("result = "..result)
  else
--    Print("result = null")
  end
  return result
end

function Oscillo:GetCurrentSize()
  return self.quantumArray:GetCurrentSize()
end