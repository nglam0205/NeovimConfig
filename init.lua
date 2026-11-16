-- ~/.config/nvim/init.lua
-- Minimal, performance-first C++ IDE for Termux/Neovim.

-- Compile Lua modules to bytecode and cache them (big startup win).
vim.loader.enable()

require("config.options")
require("config.keymaps")
require("config.pairs")
require("config.cp")
require("config.lazy")
require("config.lsp")
require("config.inline_diagnostics")
