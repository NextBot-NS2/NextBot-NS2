class 'HistoryArray'

function HistoryArray:Initialize(maxSize)
  self.maxSize = maxSize
  self.items = {}
  self.itemCount = 0
  self.currentItemIndex = 0
end

function HistoryArray:GetCurrentSize()
  return self.itemCount
end

function HistoryArray:PutValue(value)
  if self.itemCount < self.maxSize then
    -- filling to maxSize
    self.currentItemIndex = self.itemCount
    self.itemCount = self.itemCount + 1
  else
    self.currentItemIndex = self.currentItemIndex + 1
    if self.currentItemIndex >= self.maxSize then
      self.currentItemIndex = 0
    end
  end
  self.items[self.currentItemIndex] = value
end

-- indices from 0 to maxSize - 1, where 0 - newest value
function HistoryArray:GetValueByIndex(index, defaultValue)
  if (index < 0) or (index >= self.itemCount) then
    return defaultValue
  else
    local index = self.currentItemIndex - index
    if index < 0 then
      index = index + self.itemCount
    end
    return self.items[index]
  end
end

function HistoryArray:GetAvg(fromIndex, count, defaultItemValue, defaultResultValue)
  local result = defaultResultValue
  local avgCount = 0
  local avgSumm = 0
  for i = fromIndex, fromIndex + count - 1 do
    local value = self:GetValueByIndex(i, defaultItemValue)
    if value then
      avgCount = avgCount + 1
      avgSumm = avgSumm + value
    end
  end
  if avgCount > 0 then
    result = avgSumm / avgCount
  end
  return result
end