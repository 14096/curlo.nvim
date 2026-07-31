local M = {}

---@param body string
---@param filter string  jq filter expression (e.g. "." or ".items[]")
---@return string
local function format_json(body, filter)
  filter = filter or "."
  local jq_available = vim.fn.executable("jq") == 1

  if jq_available then
    local result = vim.fn.system({ "jq", filter }, body)
    if vim.v.shell_error == 0 and result and result ~= "" then
      return result
    end
    if filter ~= "." then
      vim.notify(
        string.format("[curlo] jq filter failed (exit %d): %s", vim.v.shell_error, vim.trim(result or "")),
        vim.log.levels.ERROR
      )
      return body
    end
  end

  if filter ~= "." then
    if not jq_available then
      vim.notify("[curlo] jq filter requested but `jq` is not installed; showing unfiltered body", vim.log.levels.WARN)
    end
    return body
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
---@param jq_filter string|nil  optional jq filter to apply when body is JSON
---@return string formatted_body
---@return string filetype suggested filetype for the buffer
function M.format(body, headers, cfg, jq_filter)
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
    return format_json(body, jq_filter or "."), "json"
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
