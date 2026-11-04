vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Keep the command line visible and reliable in terminal/Termux.
vim.opt.cmdheight = 1
vim.opt.laststatus = 3

require("config.options")
require("config.keymaps")
require("config.lazy")
