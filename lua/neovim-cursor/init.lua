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

-- Handler for renaming the active terminal
function M.rename_terminal_handler()
  local active_id = tabs.get_active()
  
  if not active_id then
    vim.notify("No active terminal to rename. Create one with <leader>an", vim.log.levels.WARN)
    return
  end
  
  local term = tabs.get_terminal(active_id)
  local current_name = term and term.name or ""
  
  vim.ui.input({
    prompt = "Enter new terminal name: ",
    default = current_name,
  }, function(input)
    if input and input ~= "" then
      if tabs.rename_terminal(active_id, input) then
        vim.notify("Terminal renamed to: " .. input, vim.log.levels.INFO)
      else
        vim.notify("Failed to rename terminal", vim.log.levels.ERROR)
      end
    end
  end)
end

-- Handler for closing a terminal
function M.close_terminal_handler(terminal_id)
  local id_to_close = terminal_id or tabs.get_active()
  
  if not id_to_close then
    vim.notify("No terminal to close", vim.log.levels.WARN)
    return
  end
  
  local term = tabs.get_terminal(id_to_close)
  if not term then
    vim.notify("Terminal not found", vim.log.levels.ERROR)
    return
  end
  
  -- Ask for confirmation
  vim.ui.select({"Yes", "No"}, {
    prompt = string.format("Close terminal '%s'?", term.name),
  }, function(choice)
    if choice == "Yes" then
      if tabs.delete_terminal(id_to_close) then
        vim.notify("Terminal closed: " .. term.name, vim.log.levels.INFO)
      else
        vim.notify("Failed to close terminal", vim.log.levels.ERROR)
      end
    end
  end)
end

-- Handler for listing all terminals
function M.list_terminals_handler()
  local terminals = tabs.list_terminals()
  
  if #terminals == 0 then
    vim.notify("No terminals available. Create one with <leader>an", vim.log.levels.INFO)
    return
  end
  
  local active_id = tabs.get_active()
  local lines = {"Cursor Agent Terminals:", ""}
  
  for i, term in ipairs(terminals) do
    local status = terminal.is_running(term.id) and "running" or "stopped"
    local active_marker = (term.id == active_id) and "? " or "  "
    local age_seconds = os.time() - term.created_at
    local age_str
    
    if age_seconds < 60 then
      age_str = age_seconds .. "s"
    elseif age_seconds < 3600 then
      age_str = math.floor(age_seconds / 60) .. "m"
    else
      age_str = math.floor(age_seconds / 3600) .. "h"
    end
    
    table.insert(lines, string.format("%s%d. %s [%s] (created %s ago)", 
      active_marker, i, term.name, status, age_str))
  end
  
  table.insert(lines, "")
  table.insert(lines, string.format("Total: %d terminal(s)", #terminals))
  
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
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

  -- New keybinding for renaming a terminal (<leader>ar)
  vim.keymap.set("n", "<leader>ar", M.rename_terminal_handler, {
    desc = "Rename Cursor Agent terminal",
    silent = true,
  })

  -- New keybinding for closing a terminal (<leader>ax)
  vim.keymap.set("n", "<leader>ax", M.close_terminal_handler, {
    desc = "Close Cursor Agent terminal",
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

  -- Create command to rename terminal
  vim.api.nvim_create_user_command("CursorAgentRename", function(opts)
    local active_id = tabs.get_active()
    if not active_id then
      vim.notify("No active terminal to rename", vim.log.levels.WARN)
      return
    end
    
    if opts.args and opts.args ~= "" then
      -- Name provided as argument
      if tabs.rename_terminal(active_id, opts.args) then
        vim.notify("Terminal renamed to: " .. opts.args, vim.log.levels.INFO)
      end
    else
      -- No argument, use the interactive handler
      M.rename_terminal_handler()
    end
  end, {
    desc = "Rename Cursor Agent terminal",
    nargs = "?",
  })

  -- Create command to close terminal
  vim.api.nvim_create_user_command("CursorAgentClose", function(opts)
    -- If argument provided, try to parse it as terminal ID or index
    if opts.args and opts.args ~= "" then
      -- For now, just close active terminal (can be enhanced later)
      M.close_terminal_handler()
    else
      M.close_terminal_handler()
    end
  end, {
    desc = "Close Cursor Agent terminal",
    nargs = "?",
  })

  -- Create command to list terminals
  vim.api.nvim_create_user_command("CursorAgentList", function()
    M.list_terminals_handler()
  end, {
    desc = "List all Cursor Agent terminals",
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

