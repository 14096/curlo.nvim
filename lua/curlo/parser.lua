local M = {}

---@param s string
---@return string[]
local function tokenize(s)
  local tokens = {}
  local i = 1
  local len = #s
  while i <= len do
    while i <= len and s:sub(i, i):match("%s") do
      i = i + 1
    end
    if i > len then
      break
    end

    local ch = s:sub(i, i)
    local token = ""

    if ch == '"' then
      i = i + 1
      while i <= len and s:sub(i, i) ~= '"' do
        if s:sub(i, i) == "\\" and i + 1 <= len then
          i = i + 1
          token = token .. s:sub(i, i)
        else
          token = token .. s:sub(i, i)
        end
        i = i + 1
      end
      i = i + 1
    elseif ch == "'" then
      i = i + 1
      while i <= len and s:sub(i, i) ~= "'" do
        token = token .. s:sub(i, i)
        i = i + 1
      end
      i = i + 1
    else
      while i <= len and not s:sub(i, i):match("%s") do
        token = token .. s:sub(i, i)
        i = i + 1
      end
    end

    if token ~= "" then
      table.insert(tokens, token)
    end
  end
  return tokens
end

---@param line string
---@param entering_quote string|nil  quote char already open at start of line
---@return string|nil open_quote_at_end
local function quote_state_at_end(line, entering_quote)
  local q = entering_quote
  local i = 1
  local len = #line
  while i <= len do
    local ch = line:sub(i, i)
    if q == nil then
      if ch == '"' or ch == "'" then
        q = ch
      elseif ch == "\\" then
        i = i + 1
      end
    else
      if ch == q then
        q = nil
      elseif q == '"' and ch == "\\" then
        i = i + 1
      end
    end
    i = i + 1
  end
  return q
end

---@param line string  already stripped of trailing whitespace
---@param entering_quote string|nil  quote state at the start of this line
---@return boolean is_continuation
---@return string|nil quote_state_at_end
local function is_continuation_line(line, entering_quote)
  if line:sub(-1) ~= "\\" then
    local q = quote_state_at_end(line, entering_quote)
    return false, q
  end
  local before_slash = line:sub(1, -2)
  local q = quote_state_at_end(before_slash, entering_quote)
  if q ~= nil then
    local q_full = quote_state_at_end(line, entering_quote)
    return false, q_full
  end
  return true, nil
end

---@param lines string[]
---@return string[]
local function join_continuations(lines)
  local result = {}
  local current = ""
  local open_quote = nil
  local in_command = false

  for _, line in ipairs(lines) do
    local stripped = line:gsub("%s+$", "")
    local trimmed = (stripped:gsub("^%s+", ""))
    local is_indented = stripped ~= trimmed and trimmed ~= ""
    local is_blank = trimmed == ""
    local is_comment = trimmed:sub(1, 1) == "#"

    if open_quote ~= nil then
      current = current .. " " .. stripped
      local cont, q_after = is_continuation_line(stripped, open_quote)
      if cont then
        open_quote = nil
      else
        open_quote = q_after
        if open_quote == nil then
          table.insert(result, (current:gsub("^%s+", "")))
          current = ""
          in_command = false
        end
      end
    elseif is_blank or (is_comment and not is_indented) then
      if current ~= "" then
        table.insert(result, (current:gsub("^%s+", "")))
        current = ""
        in_command = false
      end
    elseif in_command and is_indented then
      local cont, q_after = is_continuation_line(stripped, nil)
      if cont then
        current = current .. " " .. stripped:sub(1, -2)
      else
        current = current .. " " .. stripped
        open_quote = q_after
      end
    else
      if current ~= "" then
        table.insert(result, (current:gsub("^%s+", "")))
        current = ""
      end
      local cont, q_after = is_continuation_line(stripped, nil)
      if cont then
        current = stripped:sub(1, -2)
        open_quote = nil
      else
        current = stripped
        open_quote = q_after
      end
      in_command = true
    end
  end

  local tail = (current:gsub("^%s+", ""))
  if tail ~= "" then
    table.insert(result, tail)
  end

  return result
end

---@param line string
---@return string[]?
local function parse_curl_line(line)
  line = (line:gsub("^%s+", ""):gsub("%s+$", ""))
  if line == "" or line:sub(1, 1) == "#" then
    return nil
  end
  local tokens = tokenize(line)
  if #tokens == 0 then
    return nil
  end
  if tokens[1]:lower() ~= "curl" then
    table.insert(tokens, 1, "curl")
  end
  return tokens
end

---@param lines string[]
---@return string[][] list of argv token lists
function M.extract_all(lines)
  local joined = join_continuations(lines)
  local cmds = {}
  for _, line in ipairs(joined) do
    local tokens = parse_curl_line(line)
    if tokens then
      table.insert(cmds, tokens)
    end
  end
  return cmds
end

---@param lines string[]
---@param cursor_row number 1-indexed row
---@return string[]?
function M.find_at_cursor(lines, cursor_row)
  local cmd_lines = {}
  local current_start = nil
  local current_raw = {}
  local open_quote = nil
  local in_command = false

  local function flush(end_row)
    if current_start ~= nil then
      table.insert(cmd_lines, { start_row = current_start, end_row = end_row, raw = current_raw })
    end
    current_start = nil
    current_raw = {}
    open_quote = nil
    in_command = false
  end

  for i, line in ipairs(lines) do
    local stripped = line:gsub("%s+$", "")
    local trimmed = (stripped:gsub("^%s+", ""))
    local is_indented = stripped ~= trimmed and trimmed ~= ""
    local is_blank = trimmed == ""
    local is_comment = trimmed:sub(1, 1) == "#"

    if open_quote ~= nil then
      table.insert(current_raw, stripped)
      local cont, q_after = is_continuation_line(stripped, open_quote)
      if cont then
        open_quote = nil
      else
        open_quote = q_after
        if open_quote == nil then
          flush(i)
        end
      end
    elseif is_blank or (is_comment and not is_indented) then
      flush(i - 1)
    elseif in_command and is_indented then
      table.insert(current_raw, stripped)
      local cont, q_after = is_continuation_line(stripped, nil)
      if not cont then
        open_quote = q_after
      end
    else
      if current_start ~= nil then
        flush(i - 1)
      end
      current_start = i
      current_raw = { stripped }
      local cont, q_after = is_continuation_line(stripped, nil)
      if cont then
        open_quote = nil
      else
        open_quote = q_after
      end
      in_command = true
    end
  end
  if current_start ~= nil then
    flush(#lines)
  end

  for _, entry in ipairs(cmd_lines) do
    if cursor_row >= entry.start_row and cursor_row <= entry.end_row then
      local joined = join_continuations(entry.raw)
      for _, jline in ipairs(joined) do
        local tokens = parse_curl_line(jline)
        if tokens then
          return tokens
        end
      end
    end
  end
  return nil
end

return M
