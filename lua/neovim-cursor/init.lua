-- Main module for neovim-cursor plugin
local config_module = require("neovim-cursor.config")
local terminal = require("neovim-cursor.terminal")

local M = {}
local config = {}

-- Plugin version (Semantic Versioning: MAJOR.MINOR.PATCH)
M.version = "0.3.0"

-- Normal mode handler: just toggle the terminal
function M.normal_mode_handler()
  terminal.toggle(config)
end

-- Visual mode handler: toggle terminal and send selection
function M.visual_mode_handler()
  -- Get the current buffer and file path
  local buf = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(buf)

  -- Get visual selection line range
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2]
  local end_line = end_pos[2]

  -- Toggle the terminal (open if closed, show if hidden)
  terminal.toggle(config)

  -- Wait a bit for terminal to be ready, then send text
  vim.defer_fn(function()
    if terminal.is_running() then
      -- Send the filepath with @ prefix and line range (no content needed)
      local text_to_send = "@" .. filepath .. ":" .. start_line .. "-" .. end_line
      terminal.send_text(text_to_send)
    end
  end, 100)  -- 100ms delay to ensure terminal is ready
end

-- Setup function to initialize the plugin
function M.setup(user_config)
  -- Merge user config with defaults
  config = config_module.setup(user_config)

  -- Set up keybindings
  vim.keymap.set("n", config.keybinding, M.normal_mode_handler, {
    desc = "Toggle Cursor Agent terminal",
    silent = true,
  })

  vim.keymap.set("v", config.keybinding, function()
    -- Exit visual mode before processing
    local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
    vim.api.nvim_feedkeys(esc, "x", false)
    -- Call handler after exiting visual mode
    vim.schedule(M.visual_mode_handler)
  end, {
    desc = "Toggle Cursor Agent terminal and send selection",
    silent = true,
  })

  -- Create user command
  vim.api.nvim_create_user_command("CursorAgent", function()
    terminal.toggle(config)
  end, {
    desc = "Toggle Cursor Agent terminal",
  })

  -- Create command to send text manually
  vim.api.nvim_create_user_command("CursorAgentSend", function(opts)
    if terminal.is_running() then
      terminal.send_text(opts.args)
    else
      vim.notify("Cursor agent terminal is not running", vim.log.levels.WARN)
    end
  end, {
    desc = "Send text to Cursor Agent terminal",
    nargs = "+",
  })

  -- Create command to display version
  vim.api.nvim_create_user_command("CursorAgentVersion", function()
    vim.notify("neovim-cursor v" .. M.version, vim.log.levels.INFO)
  end, {
    desc = "Display neovim-cursor plugin version",
  })
end

-- Expose terminal functions for advanced usage
M.terminal = terminal

return M

