-- Terminal management for neovim-cursor plugin
--
-- This module handles the low-level terminal operations:
-- - Creating terminal buffers and windows
-- - Managing terminal visibility (show/hide)
-- - Sending text to terminal buffers
-- - Terminal lifecycle (on_exit callbacks)
-- - Terminal mode keybindings (<Esc>, <C-n>, <C-t>, <C-r>)
--
-- Architecture:
-- - Stores terminal instances with buffers, windows, and job IDs
-- - Supports multiple terminals with unique IDs
-- - Cleanup callbacks notify tabs.lua when terminals exit
-- - Buffer-local keybindings are set up for each terminal
--
local M = {}

-- State tracking for multiple terminals
local terminals = {}  -- Table of terminal instances keyed by ID (stores buf, win, job_id)
local active_id = nil  -- Currently active terminal ID
local default_id = "default"  -- Default terminal ID for backward compatibility
local cleanup_callbacks = {}  -- Callbacks to call when a terminal exits (used by tabs.lua for state sync)

-- Get a terminal instance by ID (defaults to active or default terminal)
local function get_terminal(id)
  id = id or active_id or default_id
  return terminals[id]
end

-- Check if terminal is currently visible
local function is_visible(id)
  local term = get_terminal(id)
  if not term then return false end
  return term.win ~= nil and vim.api.nvim_win_is_valid(term.win)
end

-- Check if terminal buffer exists and is valid
local function is_buffer_valid(id)
  local term = get_terminal(id)
  if not term then return false end
  return term.buf ~= nil and vim.api.nvim_buf_is_valid(term.buf)
end

-- Check if terminal is running
function M.is_running(id)
  if not is_buffer_valid(id) then
    return false
  end

  local term = get_terminal(id)
  -- Check if job is still running
  if term and term.job_id then
    local job_info = vim.fn.jobwait({term.job_id}, 0)
    return job_info[1] == -1  -- -1 means still running
  end

  return false
end

-- Hide the terminal window
local function hide(id)
  id = id or active_id or default_id
  if is_visible(id) then
    local term = get_terminal(id)
    if term then
      vim.api.nvim_win_hide(term.win)
      term.win = nil
    end
  end
end

-- Expose hide function for keymaps
function M.hide(id)
  hide(id)
end

-- Show the terminal window
local function show(id, config)
  id = id or active_id or default_id
  if not is_buffer_valid(id) then
    return false
  end

  local term = get_terminal(id)
  if not term then
    return false
  end

  -- Calculate split size
  local size
  if config.split.position == "right" or config.split.position == "left" then
    size = math.floor(vim.o.columns * config.split.size)
  else
    size = math.floor(vim.o.lines * config.split.size)
  end

  -- Create the split
  local split_cmd
  if config.split.position == "right" then
    split_cmd = "rightbelow vsplit"
  elseif config.split.position == "left" then
    split_cmd = "leftabove vsplit"
  elseif config.split.position == "top" then
    split_cmd = "leftabove split"
  else  -- bottom
    split_cmd = "rightbelow split"
  end

  vim.cmd(split_cmd)
  term.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(term.win, term.buf)

  -- Set window size
  if config.split.position == "right" or config.split.position == "left" then
    vim.api.nvim_win_set_width(term.win, size)
  else
    vim.api.nvim_win_set_height(term.win, size)
  end

  -- Update active terminal
  active_id = id

  return true
end

-- Create a new terminal instance (reusable function for creating terminals)
-- This is the extracted logic that can be used for multiple terminals
local function create_terminal_instance(id, config)
  -- Initialize terminal state if it doesn't exist
  if not terminals[id] then
    terminals[id] = {
      buf = nil,
      win = nil,
      job_id = nil,
      id = id,
    }
  end

  local term = terminals[id]

  -- Create a new buffer
  term.buf = vim.api.nvim_create_buf(false, true)

  -- Show the window
  show(id, config)

  -- Start the terminal
  term.job_id = vim.fn.termopen(config.command, {
    on_exit = function(_, exit_code, _)
      -- Clean up state when terminal exits
      term.job_id = nil
      if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
        vim.api.nvim_buf_delete(term.buf, { force = true })
      end
      term.buf = nil
      term.win = nil

      -- Remove terminal from table
      terminals[id] = nil

      -- Clear active_id if this was the active terminal
      if active_id == id then
        active_id = nil
      end

      -- Call cleanup callbacks (for tabs module to sync)
      for _, callback in ipairs(cleanup_callbacks) do
        pcall(callback, id, exit_code)
      end

      -- Call user callback if provided
      if config.term_opts.on_close then
        config.term_opts.on_close(exit_code)
      end
    end,
  })

  -- Set up buffer-local keymaps for terminal mode
  vim.api.nvim_buf_set_keymap(term.buf, 't', '<Esc>', '<C-\\><C-n>:lua require("neovim-cursor.terminal").hide()<CR>', {
    noremap = true,
    silent = true,
    desc = "Exit terminal window"
  })

  -- Set up buffer-local keymap for normal mode in terminal
  vim.api.nvim_buf_set_keymap(term.buf, 'n', '<Esc>', ':lua require("neovim-cursor.terminal").hide()<CR>', {
    noremap = true,
    silent = true,
    desc = "Hide terminal window"
  })

  -- Set up buffer-local keymap for creating new terminal from terminal mode
  -- First hide current terminal, then create new one
  vim.api.nvim_buf_set_keymap(term.buf, 't', '<C-n>', '<C-\\><C-n>:lua require("neovim-cursor").new_terminal_from_terminal_handler()<CR>', {
    noremap = true,
    silent = true,
    desc = "Create new agent terminal (hide current first)"
  })

  -- Set up buffer-local keymap for renaming current terminal from terminal mode
  vim.api.nvim_buf_set_keymap(term.buf, 't', '<C-r>', '<C-\\><C-n>:lua require("neovim-cursor").rename_terminal_handler()<CR>', {
    noremap = true,
    silent = true,
    desc = "Rename current agent window"
  })

  -- Set up buffer-local keymap for selecting terminal from terminal mode
  vim.api.nvim_buf_set_keymap(term.buf, 't', '<C-t>', '<C-\\><C-n>:lua require("neovim-cursor").select_terminal_handler()<CR>', {
    noremap = true,
    silent = true,
    desc = "Select agent terminal"
  })

  -- Enter insert mode in terminal
  vim.cmd("startinsert")

  -- Set this as the active terminal
  active_id = id

  -- Call user callback if provided
  if config.term_opts.on_open then
    config.term_opts.on_open()
  end

  return term
end

-- Create a new terminal (uses default ID for backward compatibility)
local function create(config)
  return create_terminal_instance(default_id, config)
end

-- Toggle terminal visibility
function M.toggle(config, id)
  id = id or active_id or default_id
  
  if is_visible(id) then
    -- Terminal is visible, hide it
    hide(id)
  elseif is_buffer_valid(id) and M.is_running(id) then
    -- Terminal exists but is hidden, show it
    show(id, config)
    vim.cmd("startinsert")
  else
    -- Terminal doesn't exist or isn't running, create it
    create_terminal_instance(id, config)
  end
end

-- Send text to the terminal
function M.send_text(text, id)
  id = id or active_id or default_id
  
  if not M.is_running(id) then
    vim.notify("Cursor agent terminal is not running", vim.log.levels.WARN)
    return false
  end

  local term = get_terminal(id)
  if term and term.job_id then
    -- Ensure text ends with newline
    if not text:match("\n$") then
      text = text .. "\n"
    end
    vim.api.nvim_chan_send(term.job_id, text)
    return true
  end

  return false
end

-- Get terminal state (for debugging)
function M.get_state(id)
  id = id or active_id or default_id
  local term = get_terminal(id)
  
  if not term then
    return {
      id = id,
      exists = false,
      is_visible = false,
      is_running = false,
    }
  end
  
  return {
    id = id,
    buf = term.buf,
    win = term.win,
    job_id = term.job_id,
    is_visible = is_visible(id),
    is_running = M.is_running(id),
  }
end

-- Register a cleanup callback (called when terminal exits)
-- @param callback function(id, exit_code)
function M.register_cleanup_callback(callback)
  table.insert(cleanup_callbacks, callback)
end

-- Expose internal functions for tabs module (Phase 1.4+)
M._create_terminal_instance = create_terminal_instance
M._get_terminal = get_terminal
M._set_active = function(id) active_id = id end
M._get_active_id = function() return active_id end

return M

