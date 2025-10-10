-- Terminal management for neovim-cursor plugin
local M = {}

-- State tracking
local state = {
  buf = nil,      -- Terminal buffer number
  win = nil,      -- Terminal window ID
  job_id = nil,   -- Job ID for the terminal process
}

-- Check if terminal is currently visible
local function is_visible()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

-- Check if terminal buffer exists and is valid
local function is_buffer_valid()
  return state.buf ~= nil and vim.api.nvim_buf_is_valid(state.buf)
end

-- Check if terminal is running
function M.is_running()
  if not is_buffer_valid() then
    return false
  end
  
  -- Check if job is still running
  if state.job_id then
    local job_info = vim.fn.jobwait({state.job_id}, 0)
    return job_info[1] == -1  -- -1 means still running
  end
  
  return false
end

-- Hide the terminal window
local function hide()
  if is_visible() then
    vim.api.nvim_win_hide(state.win)
    state.win = nil
  end
end

-- Show the terminal window
local function show(config)
  if not is_buffer_valid() then
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
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.win, state.buf)
  
  -- Set window size
  if config.split.position == "right" or config.split.position == "left" then
    vim.api.nvim_win_set_width(state.win, size)
  else
    vim.api.nvim_win_set_height(state.win, size)
  end
  
  return true
end

-- Create a new terminal
local function create(config)
  -- Create a new buffer
  state.buf = vim.api.nvim_create_buf(false, true)
  
  -- Show the window
  show(config)
  
  -- Start the terminal
  state.job_id = vim.fn.termopen(config.command, {
    on_exit = function(_, exit_code, _)
      -- Clean up state when terminal exits
      state.job_id = nil
      if is_buffer_valid() then
        vim.api.nvim_buf_delete(state.buf, { force = true })
      end
      state.buf = nil
      state.win = nil
      
      -- Call user callback if provided
      if config.term_opts.on_close then
        config.term_opts.on_close(exit_code)
      end
    end,
  })
  
  -- Enter insert mode in terminal
  vim.cmd("startinsert")
  
  -- Call user callback if provided
  if config.term_opts.on_open then
    config.term_opts.on_open()
  end
end

-- Toggle terminal visibility
function M.toggle(config)
  if is_visible() then
    -- Terminal is visible, hide it
    hide()
  elseif is_buffer_valid() and M.is_running() then
    -- Terminal exists but is hidden, show it
    show(config)
    vim.cmd("startinsert")
  else
    -- Terminal doesn't exist or isn't running, create it
    create(config)
  end
end

-- Send text to the terminal
function M.send_text(text)
  if not M.is_running() then
    vim.notify("Cursor agent terminal is not running", vim.log.levels.WARN)
    return false
  end
  
  if state.job_id then
    -- Ensure text ends with newline
    if not text:match("\n$") then
      text = text .. "\n"
    end
    vim.api.nvim_chan_send(state.job_id, text)
    return true
  end
  
  return false
end

-- Get terminal state (for debugging)
function M.get_state()
  return {
    buf = state.buf,
    win = state.win,
    job_id = state.job_id,
    is_visible = is_visible(),
    is_running = M.is_running(),
  }
end

return M

