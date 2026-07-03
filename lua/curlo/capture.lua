local M = {}

local MAX_RUNTIME_VARS = 200

---@type table<string,string>   lowercased name → value
local runtime_vars = {}
local runtime_keys_order = {}

function M.runtime()
  return runtime_vars
end

---@param name  string
---@param value string
function M.set_runtime(name, value)
  local key = name:lower()
  if runtime_vars[key] == nil then
    if #runtime_keys_order >= MAX_RUNTIME_VARS then
      local oldest = table.remove(runtime_keys_order, 1)
      runtime_vars[oldest] = nil
    end
    table.insert(runtime_keys_order, key)
  end
  runtime_vars[key] = value
end

function M.clear_runtime()
  runtime_vars = {}
  runtime_keys_order = {}
end

---@class CurloCapture
---@field var  string  variable name (lowercase)
---@field path string  JSON path, e.g. "$.access_token" or "$.items[0].id"

---@param line string
---@return CurloCapture|nil
local function parse_capture_line(line)
  -- @var_name <- $.path
  -- Name chars: word chars, underscore, dot, hyphen (%-  = escaped hyphen in pattern)
  local name, path = line:match("^%s*@([%w_][%w_.%-]*) *<%- *(.+)$")
  if not name then
    return nil
  end
  path = path:match("^%s*(.-)%s*$")
  if path == "" then
    return nil
  end
  return { var = name:lower(), path = path }
end

---@param lines      string[]
---@param cursor_row number  1-indexed row of any line inside the request
---@return CurloCapture[]
function M.find_captures_at_cursor(lines, cursor_row)
  local block_start = cursor_row
  while block_start > 1 do
    local t = lines[block_start - 1]:gsub("^%s+", ""):gsub("%s+$", "")
    if t == "" or t:sub(1, 1) == "#" then
      break
    end
    if t:match("^@[%w_][%w_.%-]* *<%-") or t:sub(1, 2) == ">>" then
      break
    end
    block_start = block_start - 1
  end

  local block_end = block_start
  local in_quote = nil
  for i = block_start, #lines do
    local stripped = lines[i]:gsub("%s+$", "")
    local trimmed = stripped:gsub("^%s+", "")
    if in_quote then
      if stripped:find(in_quote, 1, true) then
        in_quote = nil
      end
      block_end = i
    elseif trimmed == "" then
      break
    elseif trimmed:match("^@[%w_][%w_.%-]* *<%-") or trimmed:sub(1, 2) == ">>" then
      break
    else
      local sq = select(2, stripped:gsub("'", "")) % 2 == 1
      local dq = select(2, stripped:gsub('"', "")) % 2 == 1
      if sq then
        in_quote = "'"
      elseif dq then
        in_quote = '"'
      end
      block_end = i
    end
  end

  local captures = {}
  local blank_count = 0
  local i = block_end + 1

  while i <= #lines do
    local line = lines[i]
    local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")

    if trimmed == "" then
      blank_count = blank_count + 1
      if blank_count > 1 then
        break
      end
      i = i + 1
    elseif trimmed:sub(1, 1) == "#" then
      i = i + 1
    elseif trimmed:sub(1, 2) == ">>" then
      blank_count = 0
      i = i + 1
    else
      local cap = parse_capture_line(line)
      if cap then
        table.insert(captures, cap)
        blank_count = 0
        i = i + 1
      else
        break
      end
    end
  end

  return captures
end

---@param tbl  table
---@param path string
---@return string|nil
local function json_path(tbl, path)
  path = path:gsub("^%$%.?", "")
  if path == "" then
    return type(tbl) ~= "table" and tostring(tbl) or nil
  end

  local current = tbl
  for segment in path:gmatch("[^.]+") do
    if type(current) ~= "table" then
      return nil
    end
    local key, idx = segment:match("^([^%[]*)%[(%d+)%]$")
    if key ~= nil then
      if key ~= "" then
        current = current[key]
        if type(current) ~= "table" then
          return nil
        end
      end
      current = current[tonumber(idx) + 1]
    else
      current = current[segment]
    end
  end

  if current == nil then
    return nil
  end
  if type(current) == "table" then
    local ok, encoded = pcall(vim.json.encode, current)
    return ok and encoded or nil
  end
  return tostring(current)
end

---@param captures CurloCapture[]
---@param body     string  raw response body
function M.apply_captures(captures, body)
  if #captures == 0 then
    return
  end

  for _, cap in ipairs(captures) do
    local ok, decoded = pcall(vim.json.decode, body)
    local value = (ok and decoded) and json_path(decoded, cap.path) or nil

    if value ~= nil then
      M.set_runtime(cap.var, value)
      vim.notify(string.format("[curlo] @%s = %s", cap.var, value), vim.log.levels.INFO)
    else
      vim.notify(string.format("[curlo] capture failed: @%s <- %s", cap.var, cap.path), vim.log.levels.WARN)
    end
  end
end

return M
