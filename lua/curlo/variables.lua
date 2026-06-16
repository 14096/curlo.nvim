local capture = require("curlo.capture")

local M = {}

---@param lines string[]
---@return table<string,string>  map of lowercased name → raw value
function M.extract_definitions(lines)
  local vars = {}
  for _, line in ipairs(lines) do
    local name, value = line:match("^%s*@([%w_][%w_%-.]*) *= *(.-)%s*$")
    if name then
      vars[name:lower()] = value
    end
  end
  return vars
end

---@param path string  absolute path to the .env file
---@return table<string,string>
local function load_dotenv(path)
  local vars = {}
  local f = io.open(path, "r")
  if not f then
    return vars
  end
  for line in f:lines() do
    line = line:match("^%s*(.-)%s*$") -- trim
    if line ~= "" and line:sub(1, 1) ~= "#" then
      local key, val = line:match("^([%w_][%w_%.]*)%s*=%s*(.*)$")
      if key then
        val = val:match('^"(.*)"$') or val:match("^'(.*)'$") or val
        vars[key] = val
      end
    end
  end
  f:close()
  return vars
end

---@param curl_file_path string
---@return table<string,string>
function M.load_env_file(curl_file_path)
  if not curl_file_path or curl_file_path == "" then
    return {}
  end
  local dir = vim.fn.fnamemodify(curl_file_path, ":h")
  local env_path = dir .. "/.env"
  return load_dotenv(env_path)
end

---@param file_vars table<string,string>  from extract_definitions (lowercased keys)
---@param env_vars  table<string,string>  from load_env_file (original case keys)
---@return table<string,string>
function M.build_context(file_vars, env_vars)
  local runtime = capture.runtime()
  return setmetatable({}, {
    __index = function(_, key)
      local lkey = key:lower()
      local rv = runtime[lkey]
      if rv ~= nil then
        return rv
      end
      local fv = file_vars[lkey]
      if fv ~= nil then
        return fv
      end
      local ev = env_vars[key]
      if ev ~= nil then
        return ev
      end
      for k, v in pairs(env_vars) do
        if k:lower() == lkey then
          return v
        end
      end
      return os.getenv(key)
    end,
  })
end

---@param s string
---@param ctx table<string,string>
---@return string result
---@return string[] unresolved  names that had no value
local function substitute(s, ctx)
  local unresolved = {}
  local result = s:gsub("{{([^}]+)}}", function(name)
    name = name:match("^%s*(.-)%s*$")
    local val = ctx[name]
    if val == nil then
      table.insert(unresolved, name)
      return "{{" .. name .. "}}"
    end
    return val
  end)
  return result, unresolved
end

---@param argv string[]
---@param ctx table<string,string>
---@return string[] resolved_argv
---@return string[] unresolved  deduplicated list of unresolved names
function M.resolve_argv(argv, ctx)
  local resolved = {}
  local unresolved_set = {}
  for _, token in ipairs(argv) do
    local r, unres = substitute(token, ctx)
    table.insert(resolved, r)
    for _, name in ipairs(unres) do
      unresolved_set[name] = true
    end
  end
  local unresolved = {}
  for name in pairs(unresolved_set) do
    table.insert(unresolved, name)
  end
  return resolved, unresolved
end

return M
