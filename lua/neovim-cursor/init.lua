-- Main module for neovim-cursor plugin
local config_module = require("neovim-cursor.config")
local terminal = require("neovim-cursor.terminal")
local tabs = require("neovim-cursor.tabs")
local picker = require("neovim-cursor.picker")

local M = {}
local config = {}

-- Plugin version (Semantic Versioning: MAJOR.MINOR.PATCH)
M.version = "0.4.0"

-- Normal mode handler: smart toggle (create first terminal or show last active)
function M.normal_mode_handler()
  -- Check if any terminals exist
  if not tabs.has_terminals() then
    -- No terminals exist, create the first one
    tabs.create_terminal(nil, config)
  else
    -- Terminals exist, toggle the last active one
    local last_id = tabs.get_last()
    if last_id then
      terminal.toggle(config, last_id)
    else
      -- Fallback: create a new terminal
      tabs.create_terminal(nil, config)
    end
  end
end

-- Handler for creating a new terminal
function M.new_terminal_handler()
  tabs.create_terminal(nil, config)
end

-- Handler for selecting a terminal from picker
function M.select_terminal_handler()
  picker.pick_terminal(config, function(selected_id)
    if selected_id then
      tabs.switch_to(selected_id, config)
    end
  end)
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

  -- Ensure at least one terminal exists
  if not tabs.has_terminals() then
    tabs.create_terminal(nil, config)
  else
    -- Toggle the last active terminal
    local last_id = tabs.get_last()
    if last_id then
      terminal.toggle(config, last_id)
    end
  end

  -- Wait a bit for terminal to be ready, then send text
  vim.defer_fn(function()
    local active_id = tabs.get_active()
    if active_id and terminal.is_running(active_id) then
      -- Send the filepath with @ prefix and line range (no content needed)
      local text_to_send = "@" .. filepath .. ":" .. start_line .. "-" .. end_line
      terminal.send_text(text_to_send, active_id)
    end
  end, 100)  -- 100ms delay to ensure terminal is ready
end

-- Setup function to initialize the plugin
function M.setup(user_config)
  -- Merge user config with defaults
  config = config_module.setup(user_config)

  -- Set up keybindings for toggle (existing <leader>ai)
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

  -- New keybinding for creating a new terminal (<leader>an)
  vim.keymap.set("n", "<leader>an", M.new_terminal_handler, {
    desc = "Create new Cursor Agent terminal",
    silent = true,
  })

  -- New keybinding for selecting a terminal (<leader>at)
  vim.keymap.set("n", "<leader>at", M.select_terminal_handler, {
    desc = "Select Cursor Agent terminal",
    silent = true,
  })

  -- Create user command for toggle
  vim.api.nvim_create_user_command("CursorAgent", function()
    M.normal_mode_handler()
  end, {
    desc = "Toggle Cursor Agent terminal",
  })

  -- Create command to create new terminal
  vim.api.nvim_create_user_command("CursorAgentNew", function(opts)
    local name = opts.args and opts.args ~= "" and opts.args or nil
    tabs.create_terminal(name, config)
  end, {
    desc = "Create new Cursor Agent terminal",
    nargs = "?",
  })

  -- Create command to select terminal
  vim.api.nvim_create_user_command("CursorAgentSelect", function()
    M.select_terminal_handler()
  end, {
    desc = "Select Cursor Agent terminal",
  })

  -- Create command to send text manually
  vim.api.nvim_create_user_command("CursorAgentSend", function(opts)
    local active_id = tabs.get_active()
    if active_id and terminal.is_running(active_id) then
      terminal.send_text(opts.args, active_id)
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

-- Expose modules for advanced usage
M.terminal = terminal
M.tabs = tabs
M.picker = picker

return M

