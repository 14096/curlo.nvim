---@class CurloFloatConfig
---@field width number  Width of the floating window (columns). Default: 0.6 (60% of editor width when <= 1.0, absolute columns otherwise)
---@field height number Height of the floating window (rows).   Default: 0.8 (80% of editor height when <= 1.0, absolute rows otherwise)
---@field border string|table Border style passed to nvim_open_win. Default: "rounded"
---@field title string|nil Optional title shown in the border. Default: " curlo "

---@class CurloConfig
---@field keymap string Keymap to invoke curl under cursor. Default: "<leader>cc"
---@field keymap_opts table Options forwarded to vim.keymap.set.
---@field display "vsplit"|"split"|"float"|"tab" How to open the result. Default: "vsplit"
---@field result_win_width number Width of the vsplit result window (columns). Default: 80
---@field result_win_height number Height of the split result window (rows). Default: 20
---@field float CurloFloatConfig Floating window settings (used when display == "float").
---@field show_headers boolean Prepend response headers to the result buffer. Default: false
---@field format_json boolean Auto-format JSON responses. Default: true
---@field format_xml boolean Auto-format XML responses. Default: true
local defaults = {
  keymap = "<leader>cc",
  keymap_opts = { noremap = true, silent = true, desc = "Run curl under cursor" },
  display = "vsplit",
  result_win_width = 80,
  result_win_height = 20,
  float = {
    width = 0.6,
    height = 0.8,
    border = "rounded",
    title = " curlo ",
  },
  show_headers = false,
  format_json = true,
  format_xml = true,
}

local M = {}

---@type CurloConfig
M.values = vim.deepcopy(defaults)

---@param user CurloConfig?
function M.setup(user)
  M.values = vim.tbl_deep_extend("force", vim.deepcopy(defaults), user or {})
end

return M
