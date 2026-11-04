vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.smartindent = true
vim.opt.autoindent = true

vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.wrap = false
vim.opt.scrolloff = 6
vim.opt.sidescrolloff = 6

vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.mouse = "a"

-- Chỉ dùng clipboard hệ thống khi đã cài Termux:API.
if vim.fn.executable("termux-clipboard-get") == 1
  and vim.fn.executable("termux-clipboard-set") == 1 then
  vim.opt.clipboard = "unnamedplus"
end

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undofile = true

vim.opt.updatetime = 500
vim.opt.timeoutlen = 300

vim.opt.completeopt = { "menu", "menuone", "noselect" }
