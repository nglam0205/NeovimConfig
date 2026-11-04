vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Giữ command line hiển thị ổn định trong terminal/Termux.
vim.opt.cmdheight = 1
vim.opt.laststatus = 3

require("config.options")
require("config.keymaps")
require("config.lazy")
