# neovim-cursor

A Neovim plugin to integrate the Cursor AI agent CLI directly into your editor. Toggle a terminal running `cursor agent`
with a simple keybinding and send visual selections for AI assistance.

This was created using cursor 😊 basically to met my requirements of having a cursor agent in the CLI.


## Features

- 🚀 Toggle a vertical split terminal running `cursor agent` with `<leader>ai`
- 📝 Send visual selections and file paths to the Cursor agent
- 💾 Persistent terminal session (hide/show without restarting)
- ⚙️ Fully configurable (keybindings, split position, size, etc.)
- 🎯 Written in pure Lua


## Requirements

- Neovim >= 0.8.0
- `cursor` CLI installed and available in your PATH


## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "felixcuello/neovim-cursor",
  config = function()
    require("neovim-cursor").setup()
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "felixcuello/neovim-cursor",
  config = function()
    require("neovim-cursor").setup()
  end,
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'felixcuello/neovim-cursor'

lua << EOF
require("neovim-cursor").setup()
EOF
```

## Usage

### Basic Usage

1. **Open/Toggle Terminal**: Press `<leader>ai` in normal mode to open a vertical split with the Cursor agent
2. **Hide Terminal**: Press `<leader>ai` again to hide the terminal (keeps the session running), or press `<Esc>` while in the terminal
3. **Show Terminal**: Press `<leader>ai` again to show the hidden terminal

### Visual Mode

1. Select text in visual mode (v, V, or Ctrl-v)
2. Press `<leader>ai`
3. The plugin will:
   - Toggle the terminal (open/show it)
   - Send the file path with `@` prefix
   - Send the selected text

Example output sent to terminal:
```
@/path/to/your/file.lua
function hello()
  print("Hello, world!")
end
```

### Commands

The plugin also provides user commands:

- `:CursorAgent` - Toggle the Cursor agent terminal
- `:CursorAgentSend <text>` - Send arbitrary text to the terminal

## Configuration

### Default Configuration

```lua
require("neovim-cursor").setup({
  -- Keybinding for toggling cursor agent
  keybinding = "<leader>ai",

  -- Terminal split configuration
  split = {
    position = "right",  -- "right", "left", "top", "bottom"
    size = 0.5,          -- 50% of editor width/height (0.0-1.0)
  },

  -- CLI command to run
  command = "cursor agent",

  -- Terminal callbacks (optional)
  term_opts = {
    on_open = function()
      -- Called when terminal opens
      print("Cursor agent started")
    end,
    on_close = function(exit_code)
      -- Called when terminal closes
      print("Cursor agent exited with code: " .. exit_code)
    end,
  },
})
```

### Custom Configuration Examples

#### Left split with 40% width

```lua
require("neovim-cursor").setup({
  split = {
    position = "left",
    size = 0.4,
  },
})
```

#### Custom keybinding

```lua
require("neovim-cursor").setup({
  keybinding = "<C-a>",  -- Use Ctrl+a instead
})
```

#### Custom command with arguments

```lua
require("neovim-cursor").setup({
  command = "cursor agent --model gpt-4",
})
```

## Advanced Usage

### Programmatic Access

You can access the terminal functions directly:

```lua
local cursor = require("neovim-cursor")

-- Toggle terminal
cursor.normal_mode_handler()

-- Send text programmatically
cursor.terminal.send_text("@myfile.lua\nExplain this code")

-- Check if terminal is running
if cursor.terminal.is_running() then
  print("Terminal is running")
end

-- Get terminal state (for debugging)
local state = cursor.terminal.get_state()
print(vim.inspect(state))
```

## Troubleshooting

### Terminal doesn't open

- Ensure the `cursor` CLI is installed and in your PATH
- Try running `cursor agent` manually in your terminal to verify it works
- Check for errors with `:messages`

### Keybinding doesn't work

- Make sure `<leader>` is set in your config (e.g., `vim.g.mapleader = " "`)
- Check for conflicting keybindings with `:verbose map <leader>ai`

### Visual selection not working

- Ensure you're pressing `<leader>ai` while still in visual mode
- The selection will be sent after the terminal opens/shows

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) for details

## Related Projects

- [Cursor](https://cursor.sh/) - The AI-first code editor
- [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim) - Terminal management for Neovim
- [vim-floaterm](https://github.com/voldikss/vim-floaterm) - Floating terminal plugin

## Acknowledgments

Built with ❤️ for the Neovim and Cursor communities.
