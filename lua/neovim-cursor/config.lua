-- Default configuration for neovim-cursor plugin
local M = {}

M.defaults = {
  -- Keybinding for toggling cursor agent
  keybinding = "<leader>ai",

  -- Terminal split configuration
  split = {
    position = "right",  -- right, left, top, bottom
    size = 0.5,          -- 50% of editor width/height
  },

  -- CLI command to run
  command = "cursor agent",

  -- Terminal options
  term_opts = {
    on_open = nil,   -- Callback when terminal opens
    on_close = nil,  -- Callback when terminal closes
  },
}

-- Merge user config with defaults
function M.setup(user_config)
  user_config = user_config or {}
  return vim.tbl_deep_extend("force", M.defaults, user_config)
end

return M

