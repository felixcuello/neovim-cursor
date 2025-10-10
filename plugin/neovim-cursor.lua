-- Plugin entry point for neovim-cursor
-- This file is automatically loaded by Neovim

-- Prevent loading the plugin twice
if vim.g.loaded_neovim_cursor then
  return
end
vim.g.loaded_neovim_cursor = true

-- Setup the plugin with default configuration
-- Users can override this by calling require('neovim-cursor').setup() in their config
require("neovim-cursor").setup()

