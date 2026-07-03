local window = require("curlo.window")
local capture = require("curlo.capture")

local M = {}

---@param argv string[]
---@return string
local function argv_to_str(argv)
  local parts = {}
  for _, a in ipairs(argv) do
    if a:find("%s") then
      table.insert(parts, string.format('"%s"', a))
    else
      table.insert(parts, a)
    end
  end
  return table.concat(parts, " ")
end

---@param argv string[]
---@return string url   first https?:// token, or ""
---@return string method  value of -X/--request flag, or ""
local function extract_request_info(argv)
  local url = ""
  local method = ""
  local i = 1
  while i <= #argv do
    local a = argv[i]
    if a:match("^https?://") then
      url = a
    elseif (a == "-X" or a == "--request") and argv[i + 1] then
      method = argv[i + 1]
      i = i + 1
    end
    i = i + 1
  end
  return url, method
end

---@param argv string[]
---@return string[] modified_argv
---@return string   header_tmp_path
local function inject_header_capture(argv)
  local tmp = vim.fn.tempname()
  local result = { argv[1] } -- "curl"
  table.insert(result, "-D")
  table.insert(result, tmp)
  table.insert(result, "-s")
  for i = 2, #argv do
    table.insert(result, argv[i])
  end
  return result, tmp
end

---@param argv     string[]
---@param cfg      CurloConfig
---@param captures CurloCapture[]|nil  optional capture directives to apply after response
function M.run(argv, cfg, captures)
  captures = captures or {}
  local cmd_str = argv_to_str(argv)
  local url, method = extract_request_info(argv)
  local modified_argv, header_tmp = inject_header_capture(argv)

  local cancel_spinner = window.show_loading(cmd_str, cfg)

  local function on_done(body, headers, stderr, exit_code)
    cancel_spinner()
    if exit_code ~= 0 and body == "" then
      window.show_error(string.format("curl exited with code %d\n\n%s", exit_code, stderr), cfg)
      return
    end
    capture.apply_captures(captures, body)
    window.show_result(body, headers, cfg, { url = url, method = method })
  end

  vim.system(modified_argv, { text = true }, function(result)
    vim.schedule(function()
      local body = result.stdout or ""
      local stderr = result.stderr or ""
      local headers = ""
      local hf = io.open(header_tmp, "r")
      if hf then
        headers = hf:read("*a")
        hf:close()
        os.remove(header_tmp)
      end
      on_done(body, headers, stderr, result.code)
    end)
  end)
end

return M
