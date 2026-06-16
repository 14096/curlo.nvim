local config = require("curlo.config")
local parser = require("curlo.parser")
local runner = require("curlo.runner")
local variables = require("curlo.variables")
local history = require("curlo.history")
local window = require("curlo.window")
local capture = require("curlo.capture")

local M = {}

---@param argv     string[]
---@param lines    string[]   full buffer lines (for @var extraction)
---@param captures CurloCapture[]  directives to apply after the response
local function resolve_and_run(argv, lines, captures)
  local file_vars = variables.extract_definitions(lines)
  local curl_path = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  local env_vars = variables.load_env_file(curl_path)
  local ctx = variables.build_context(file_vars, env_vars)

  local resolved, unresolved = variables.resolve_argv(argv, ctx)

  if #unresolved > 0 then
    vim.notify("[curlo] Unresolved variables: " .. table.concat(unresolved, ", "), vim.log.levels.WARN)
  end

  runner.run(resolved, config.values, captures)
end

function M.run_curl_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1]

  local argv = parser.find_at_cursor(lines, cursor_row)
  if not argv then
    vim.notify("[curlo] No curl command found at cursor", vim.log.levels.WARN)
    return
  end

  local captures = capture.find_captures_at_cursor(lines, cursor_row)
  resolve_and_run(argv, lines, captures)
end

function M.run_all()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cmds = parser.extract_all(lines)
  if #cmds == 0 then
    vim.notify("[curlo] No curl commands found in buffer", vim.log.levels.WARN)
    return
  end
  local cmd_rows = {}
  local cmd_idx = 1
  local in_cmd = false
  for i, line in ipairs(lines) do
    local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" or trimmed:sub(1, 1) == "#" then
      in_cmd = false
    else
      if not in_cmd then
        cmd_rows[cmd_idx] = i
        cmd_idx = cmd_idx + 1
        in_cmd = true
      end
    end
  end
  for i, argv in ipairs(cmds) do
    local row = cmd_rows[i] or 1
    local caps = capture.find_captures_at_cursor(lines, row)
    resolve_and_run(argv, lines, caps)
  end
end

function M.open_history()
  local entries = history.all()
  if #entries == 0 then
    vim.notify("[curlo] No history yet", vim.log.levels.INFO)
    return
  end

  local items = {}
  for i = #entries, 1, -1 do
    local e = entries[i]
    local req = e.request or {}
    local method = (req.method and req.method ~= "") and (req.method .. " ") or "GET "
    local url = req.url or "(unknown)"
    local status = e.headers and (e.headers:match("^HTTP/[^\r\n]+") or "") or ""
    table.insert(items, {
      index = i,
      label = string.format("[%s]  %s%s  %s", e.timestamp or "??:??:??", method, url, status),
      entry = e,
    })
  end

  vim.ui.select(items, {
    prompt = "curlo history",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end
    history.jump(choice.index)
    window.open_entry(choice.entry, config.values)
  end)
end

---@param user_config CurloConfig?
function M.setup(user_config)
  config.setup(user_config)

  local group = vim.api.nvim_create_augroup("curlo_nvim", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "curl",
    callback = function(ev)
      local buf = ev.buf
      local opts = vim.tbl_extend("force", config.values.keymap_opts, { buffer = buf })
      vim.keymap.set("n", config.values.keymap, M.run_curl_at_cursor, opts)
    end,
  })

  vim.api.nvim_create_user_command("CurloRun", M.run_curl_at_cursor, { desc = "Run the curl command under the cursor" })
  vim.api.nvim_create_user_command("CurloRunAll", M.run_all, { desc = "Run all curl commands in the current buffer" })
  vim.api.nvim_create_user_command(
    "CurloHistory",
    M.open_history,
    { desc = "Browse session history of curl responses" }
  )
  vim.api.nvim_create_user_command("CurloReset", function()
    capture.clear_runtime()
    vim.notify("[curlo] Runtime variables cleared", vim.log.levels.INFO)
  end, { desc = "Clear all captured runtime variables" })
end

return M
