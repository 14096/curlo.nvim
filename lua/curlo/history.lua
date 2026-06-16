local M = {}

---@class CurloHistoryEntry
---@field body     string
---@field headers  string
---@field filetype string
---@field request  {url:string, method:string}
---@field timestamp string  human-readable, e.g. "14:03:22"

local MAX_HISTORY = 100

local entries = {}
local cursor = 0

local function clamp(n, lo, hi)
  if n < lo then
    return lo
  end
  if n > hi then
    return hi
  end
  return n
end

---@param entry CurloHistoryEntry
function M.push(entry)
  entry.timestamp = os.date("%H:%M:%S")
  table.insert(entries, entry)
  if #entries > MAX_HISTORY then
    table.remove(entries, 1)
  end
  cursor = #entries
end

---@return CurloHistoryEntry|nil
function M.prev()
  if #entries == 0 then
    return nil
  end
  cursor = clamp(cursor - 1, 1, #entries)
  return entries[cursor]
end

---@return CurloHistoryEntry|nil
function M.next()
  if #entries == 0 then
    return nil
  end
  cursor = clamp(cursor + 1, 1, #entries)
  return entries[cursor]
end

---@return CurloHistoryEntry|nil
function M.current()
  if cursor == 0 or #entries == 0 then
    return nil
  end
  return entries[cursor]
end

---@return number
function M.count()
  return #entries
end

---@return number
function M.position()
  return cursor
end

---@return CurloHistoryEntry[]
function M.all()
  return entries
end

---@param i number 1-based index
---@return CurloHistoryEntry|nil
function M.jump(i)
  if #entries == 0 then
    return nil
  end
  cursor = clamp(i, 1, #entries)
  return entries[cursor]
end

return M
