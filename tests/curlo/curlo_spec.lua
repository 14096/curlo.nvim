local parser = require("curlo.parser")

describe("curlo.parser", function()
  describe("find_at_cursor", function()
    it("finds a simple single-line curl command", function()
      local lines = {
        "curl https://example.com",
      }
      local argv = parser.find_at_cursor(lines, 1)
      assert.is_not_nil(argv)
      assert.equals("curl", argv[1])
      assert.equals("https://example.com", argv[2])
    end)

    it("finds a multi-line curl command (continuation lines)", function()
      local lines = {
        "curl \\",
        "  -H 'Accept: application/json' \\",
        "  https://api.example.com/v1/users",
      }
      local argv = parser.find_at_cursor(lines, 2)
      assert.is_not_nil(argv)
      assert.equals("curl", argv[1])
      -- should contain the header flag and URL
      local found_h = false
      local found_url = false
      for _, t in ipairs(argv) do
        if t == "-H" then
          found_h = true
        end
        if t == "https://api.example.com/v1/users" then
          found_url = true
        end
      end
      assert.is_true(found_h)
      assert.is_true(found_url)
    end)

    it("returns nil for a cursor on a blank line", function()
      local lines = {
        "curl https://example.com",
        "",
        "curl https://other.com",
      }
      local argv = parser.find_at_cursor(lines, 2)
      assert.is_nil(argv)
    end)

    it("returns nil for a cursor on a comment line", function()
      local lines = {
        "# This is a comment",
        "curl https://example.com",
      }
      local argv = parser.find_at_cursor(lines, 1)
      assert.is_nil(argv)
    end)

    it("distinguishes two separate commands", function()
      local lines = {
        "curl https://first.com",
        "",
        "curl https://second.com",
      }
      local argv1 = parser.find_at_cursor(lines, 1)
      local argv2 = parser.find_at_cursor(lines, 3)
      assert.is_not_nil(argv1)
      assert.is_not_nil(argv2)
      assert.equals("https://first.com", argv1[2])
      assert.equals("https://second.com", argv2[2])
    end)
  end)

  describe("extract_all", function()
    it("extracts multiple commands", function()
      local lines = {
        "curl https://one.com",
        "",
        "curl https://two.com",
        "# comment",
        "curl https://three.com",
      }
      local cmds = parser.extract_all(lines)
      assert.equals(3, #cmds)
    end)

    it("extracts zero commands from blank/comment-only buffer", function()
      local lines = { "", "# only a comment", "" }
      local cmds = parser.extract_all(lines)
      assert.equals(0, #cmds)
    end)

    it("prepends 'curl' when missing", function()
      local lines = { "https://example.com -X POST" }
      local cmds = parser.extract_all(lines)
      assert.equals(1, #cmds)
      assert.equals("curl", cmds[1][1])
    end)
  end)
end)

describe("curlo setup", function()
  it("setup merges config correctly", function()
    local curlo = require("curlo")
    local config = require("curlo.config")
    curlo.setup({ keymap = "<leader>cr", result_win_width = 100 })
    assert.equals("<leader>cr", config.values.keymap)
    assert.equals(100, config.values.result_win_width)
    -- defaults preserved
    assert.equals(true, config.values.format_json)
  end)
end)
