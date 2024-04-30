local addon = select(2, ...)

local TSM = {}
addon.TSM = TSM

-- TSM4
local TSM_API = _G.TSM_API

function TSM.IsLoaded()
  if TSM_API then
    return true
  end
  return false
end

function TSM.GetGroups()
  if not TSM.IsLoaded() then
    return
  end

  local groups = {}

  -- filter
  local tsmGroups = {}
  TSM_API.GetGroupPaths(tsmGroups)

  for k, v in pairs(tsmGroups) do
    table.insert(groups, k, v)
  end

  return groups
end

function TSM.FormatGroupPath(path)
  if not TSM.IsLoaded() then
    return
  end

  return TSM_API.FormatGroupPath(path)
end

function TSM.SplitGroupPath(path)
  if not TSM.IsLoaded() then
    return
  end

  return TSM_API.SplitGroupPath(path)
end

function TSM.GetGroupItems(path, includeSubGroups, result)
  if not TSM.IsLoaded() then
    return
  end

  return TSM_API.GetGroupItems(path, includeSubGroups, result)
end

function TSM.GetItemName(itemString)
  if not TSM.IsLoaded() then
    return itemString
  end

  return TSM_API.GetItemName(itemString)
end
