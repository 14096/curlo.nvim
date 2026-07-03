local history = require("curlo.history")
local M = {}
local RESULT_BUF_NAME = "curlo://result"

local state = {}

---@return number bufnr
local function get_or_create_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      if vim.api.nvim_buf_get_name(buf):find(RESULT_BUF_NAME, 1, true) then
        return buf
      end
    end
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, RESULT_BUF_NAME)
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      state[buf] = nil
    end,
  })
  return buf
end

---@param bufnr number
---@return number|nil winid
local function find_result_win(bufnr)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      return win
    end
  end
  return nil
end

---@param bufnr number
---@param content string[]
---@param filetype string
local function fill_buf(bufnr, content, filetype)
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_set_option_value("readonly", false, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
end

local function resolve_dim(value, total)
  return math.floor(value <= 1.0 and total * value or value)
end

local function open_vsplit(bufnr, cfg)
  vim.cmd("vsplit")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, bufnr)
  vim.api.nvim_win_set_width(win, cfg.result_win_width)
  return win
end

local function open_split(bufnr, cfg)
  vim.cmd("split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, bufnr)
  vim.api.nvim_win_set_height(win, cfg.result_win_height)
  return win
end

local function open_float(bufnr, cfg)
  local fc = cfg.float
  local ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
  local w = resolve_dim(fc.width, ui.width)
  local h = resolve_dim(fc.height, ui.height)
  local opts = {
    relative = "editor",
    width = w,
    height = h,
    row = math.floor((ui.height - h) / 2),
    col = math.floor((ui.width - w) / 2),
    style = "minimal",
    border = fc.border or "rounded",
    zindex = 50,
  }
  if fc.title and fc.title ~= "" and vim.fn.has("nvim-0.9") == 1 then
    opts.title = fc.title
    opts.title_pos = "center"
  end
  local win = vim.api.nvim_open_win(bufnr, true, opts)
  vim.api.nvim_set_option_value("winblend", 0, { win = win })
  vim.api.nvim_set_option_value("cursorline", true, { win = win })
  return win
end

local function open_tab(bufnr)
  vim.cmd("tabnew")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, bufnr)
  return win
end

local HELP_LINES = {
  "  curlo.nvim — result window keymaps   ",
  " ────────────────────────────────────  ",
  "  q   close this window               ",
  "  H   toggle response headers         ",
  "  [   previous response in history    ",
  "  ]   next response in history        ",
  "  ?   show / close this help          ",
}

local function open_help_float()
  local width = 42
  local height = #HELP_LINES
  local ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, HELP_LINES)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "curlohelp", { buf = buf })
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((ui.height - height) / 2),
    col = math.floor((ui.width - width) / 2),
    style = "minimal",
    border = "rounded",
    zindex = 100,
  }
  if vim.fn.has("nvim-0.9") == 1 then
    opts.title = " curlo help "
    opts.title_pos = "center"
  end
  local win = vim.api.nvim_open_win(buf, true, opts)
  vim.api.nvim_set_option_value("cursorline", false, { win = win })
  return win, buf
end

---@param bufnr number
---@return string[] lines
---@return string   filetype
local function build_from_state(bufnr)
  local s = state[bufnr]
  local formatter = require("curlo.formatter")
  local formatted, ft = formatter.format(s.body, s.headers, s.cfg)
  local lines = {}

  local req = s.request or {}
  if req.url and req.url ~= "" then
    local method_prefix = (req.method and req.method ~= "") and (req.method .. "  ") or ""
    table.insert(lines, "  " .. method_prefix .. req.url)
    table.insert(lines, string.rep("─", 40))
    table.insert(lines, "")
  end

  local pos = history.position()
  local total = history.count()
  if total > 0 then
    table.insert(lines, string.format("  [%d / %d]  %s", pos, total, s.timestamp or ""))
    table.insert(lines, "")
  end

  if s.cfg.show_headers and s.headers ~= "" then
    for hline in s.headers:gmatch("[^\r\n]+") do
      table.insert(lines, hline)
    end
    table.insert(lines, "")
    table.insert(lines, string.rep("─", 40))
    table.insert(lines, "")
  else
    local status_line = s.headers:match("^HTTP/[^\r\n]+") or ""
    if status_line ~= "" then
      table.insert(lines, "# " .. status_line)
      table.insert(lines, "")
    end
  end

  for line in formatted:gmatch("[^\n]+") do
    table.insert(lines, line)
  end

  return lines, ft
end

---@param entry CurloHistoryEntry
---@param cfg   CurloConfig        used only for display/window options
local function load_entry(bufnr, entry, cfg)
  state[bufnr] = {
    body = entry.body,
    headers = entry.headers,
    request = entry.request or {},
    timestamp = entry.timestamp,
    cfg = vim.tbl_extend("force", vim.deepcopy(cfg), { show_headers = false }),
  }
  local content, ft = build_from_state(bufnr)
  fill_buf(bufnr, content, ft)
end

---@param content  string[]
---@param filetype string
---@param cfg      CurloConfig
function M.show(content, filetype, cfg)
  local bufnr = get_or_create_buf()
  fill_buf(bufnr, content, filetype)

  local existing_win = find_result_win(bufnr)
  if existing_win then
    vim.api.nvim_set_current_win(existing_win)
  else
    local mode = cfg.display or "vsplit"
    if mode == "split" then
      open_split(bufnr, cfg)
    elseif mode == "float" then
      open_float(bufnr, cfg)
    elseif mode == "tab" then
      open_tab(bufnr)
    else
      open_vsplit(bufnr, cfg)
    end
  end

  vim.keymap.set("n", "q", function()
    local win = find_result_win(bufnr)
    if win then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = bufnr, silent = true, desc = "Close curlo result" })

  local help_win = nil
  vim.keymap.set("n", "?", function()
    if help_win and vim.api.nvim_win_is_valid(help_win) then
      vim.api.nvim_win_close(help_win, true)
      help_win = nil
      return
    end
    local win, hbuf = open_help_float()
    help_win = win
    local close = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      help_win = nil
    end
    vim.keymap.set("n", "q", close, { buffer = hbuf, silent = true })
    vim.keymap.set("n", "?", close, { buffer = hbuf, silent = true })
    vim.keymap.set("n", "<Esc>", close, { buffer = hbuf, silent = true })
  end, { buffer = bufnr, silent = true, desc = "Show curlo help" })
end

---@param path        string
---@param body        string  raw response body
---@param headers     string  raw response headers
---@param cfg         CurloConfig
local function write_to_file(path, body, headers, cfg)
  local formatter = require("curlo.formatter")
  local formatted = formatter.format(body, headers, cfg)
  path = vim.fn.expand(path)
  local f, err = io.open(path, "w")
  if not f then
    vim.notify("[curlo] Could not write to file: " .. (err or path), vim.log.levels.ERROR)
    return
  end
  f:write(formatted)
  f:close()
  vim.notify("[curlo] Response written to " .. path, vim.log.levels.INFO)
end

---@param body     string
---@param headers  string
---@param cfg      CurloConfig
---@param request  {url:string, method:string}
---@param output_file string|nil  optional file path to write the formatted body
function M.show_result(body, headers, cfg, request, output_file)
  local bufnr = get_or_create_buf()

  local entry = {
    body = body,
    headers = headers,
    request = request or {},
  }
  history.push(entry)

  state[bufnr] = {
    body = body,
    headers = headers,
    request = request or {},
    timestamp = history.current().timestamp,
    cfg = vim.tbl_extend("force", vim.deepcopy(cfg), { show_headers = false }),
  }

  local content, ft = build_from_state(bufnr)
  M.show(content, ft, cfg)

  if output_file then
    write_to_file(output_file, body, headers, cfg)
  end

  vim.keymap.set("n", "H", function()
    local s = state[bufnr]
    if not s then
      return
    end
    s.cfg.show_headers = not s.cfg.show_headers
    local nc, nft = build_from_state(bufnr)
    fill_buf(bufnr, nc, nft)
    vim.notify("[curlo] " .. (s.cfg.show_headers and "headers shown" or "headers hidden"), vim.log.levels.INFO)
  end, { buffer = bufnr, silent = true, desc = "Toggle response headers" })

  vim.keymap.set("n", "[", function()
    local s = state[bufnr]
    if not s then
      return
    end
    local prev = history.prev()
    if prev then
      load_entry(bufnr, prev, s.cfg)
    else
      vim.notify("[curlo] Already at oldest entry", vim.log.levels.INFO)
    end
  end, { buffer = bufnr, silent = true, desc = "Previous curl response" })

  vim.keymap.set("n", "]", function()
    local s = state[bufnr]
    if not s then
      return
    end
    local nxt = history.next()
    if nxt then
      load_entry(bufnr, nxt, s.cfg)
    else
      vim.notify("[curlo] Already at newest entry", vim.log.levels.INFO)
    end
  end, { buffer = bufnr, silent = true, desc = "Next curl response" })
end

---@param entry CurloHistoryEntry
---@param cfg   CurloConfig
function M.open_entry(entry, cfg)
  local bufnr = get_or_create_buf()
  load_entry(bufnr, entry, cfg)
  local content, ft = build_from_state(bufnr)
  M.show(content, ft, cfg)

  vim.keymap.set("n", "H", function()
    local s = state[bufnr]
    if not s then
      return
    end
    s.cfg.show_headers = not s.cfg.show_headers
    local nc, nft = build_from_state(bufnr)
    fill_buf(bufnr, nc, nft)
    vim.notify("[curlo] " .. (s.cfg.show_headers and "headers shown" or "headers hidden"), vim.log.levels.INFO)
  end, { buffer = bufnr, silent = true, desc = "Toggle response headers" })

  vim.keymap.set("n", "[", function()
    local s = state[bufnr]
    local prev = history.prev()
    if prev then
      load_entry(bufnr, prev, s and s.cfg or cfg)
    else
      vim.notify("[curlo] Already at oldest entry", vim.log.levels.INFO)
    end
  end, { buffer = bufnr, silent = true, desc = "Previous curl response" })

  vim.keymap.set("n", "]", function()
    local s = state[bufnr]
    local nxt = history.next()
    if nxt then
      load_entry(bufnr, nxt, s and s.cfg or cfg)
    else
      vim.notify("[curlo] Already at newest entry", vim.log.levels.INFO)
    end
  end, { buffer = bufnr, silent = true, desc = "Next curl response" })
end

local SPINNER_FRAMES = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

---@param cmd_str string
---@param cfg CurloConfig
---@return fun() cancel
function M.show_loading(cmd_str, cfg)
  local bufnr = get_or_create_buf()
  local start_ms = vim.uv.now()
  local frame = 1

  local function make_lines(spinner, elapsed_s)
    return {
      "",
      string.format("  %s  Running...  (%ds)", spinner, elapsed_s),
      "",
      "  " .. cmd_str,
      "",
    }
  end

  M.show(make_lines(SPINNER_FRAMES[frame], 0), "markdown", cfg)

  local timer = vim.uv.new_timer()
  timer:start(100, 100, function()
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        timer:stop()
        timer:close()
        return
      end
      frame = (frame % #SPINNER_FRAMES) + 1
      local elapsed_s = math.floor((vim.uv.now() - start_ms) / 1000)
      local lines = make_lines(SPINNER_FRAMES[frame], elapsed_s)
      vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
    end)
  end)

  return function()
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end
end

---@param msg string
---@param cfg CurloConfig
function M.show_error(msg, cfg)
  M.show(vim.split("# Error\n\n" .. msg, "\n"), "markdown", cfg)
end

return M
