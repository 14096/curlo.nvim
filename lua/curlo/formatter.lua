local M = {}

---@param body string
---@return string
local function format_json(body)
  if vim.fn.executable("jq") == 1 then
    local result = vim.fn.system({ "jq", "." }, body)
    if vim.v.shell_error == 0 and result and result ~= "" then
      return result
    end
  end

  if vim.fn.executable("python3") == 1 then
    local result = vim.fn.system({ "python3", "-m", "json.tool" }, body)
    if vim.v.shell_error == 0 and result and result ~= "" then
      return result
    end
  end

  local ok, decoded = pcall(vim.json.decode, body)
  if ok then
    local ok2, encoded = pcall(vim.json.encode, decoded)
    if ok2 then
      return encoded
    end
  end

  return body
end

---@param body string
---@return string
local function format_xml(body)
  if vim.fn.executable("xmllint") == 1 then
    local result = vim.fn.system({ "xmllint", "--format", "-" }, body)
    if vim.v.shell_error == 0 and result and result ~= "" then
      return result
    end
  end
  return body
end

---@param body string Raw response body
---@param headers string Raw response headers (optional)
---@param cfg CurloConfig
---@return string formatted_body
---@return string filetype suggested filetype for the buffer
function M.format(body, headers, cfg)
  headers = headers or ""
  local ct = ""

  for line in headers:gmatch("[^\r\n]+") do
    local val = line:match("^[Cc]ontent%-[Tt]ype:%s*(.+)$")
    if val then
      ct = val:lower()
      break
    end
  end

  if cfg.format_json and (ct:find("application/json") or ct:find("text/json") or body:match("^%s*[%[{]")) then
    return format_json(body), "json"
  end

  if
    cfg.format_xml
    and (ct:find("application/xml") or ct:find("text/xml") or ct:find("text/html") or body:match("^%s*<"))
  then
    return format_xml(body), "xml"
  end

  return body, "text"
end

return M
