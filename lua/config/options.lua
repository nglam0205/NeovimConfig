local opt = vim.opt

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.g.have_nerd_font = true

-- UI: VS Code-like, borderless.
opt.termguicolors = true
opt.winborder = "none" -- Neovim >= 0.11: no floating-window borders.
opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.showmatch = true
opt.matchtime = 2
opt.showtabline = 2
opt.laststatus = 3
opt.cmdheight = 1
opt.splitright = true
opt.splitbelow = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false
opt.list = false
opt.pumheight = 10
opt.pumwidth = 15
opt.background = "dark"

-- Indentation (C++ friendly).
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.expandtab = true
opt.autoindent = true
opt.smartindent = true
opt.breakindent = true
opt.shiftround = true
opt.cindent = true
opt.cinoptions:append(":0") -- do not indent case labels.

-- Line spacing. The TUI cannot change terminal cell metrics; the terminal
-- emulator/font must do it. GUI Neovim honours this option.
opt.linespace = 2

-- Editing / performance.
local undo_dir = vim.fn.stdpath("state") .. "/undo"
vim.fn.mkdir(undo_dir, "p")
opt.undodir = undo_dir
opt.undofile = true
opt.undolevels = 1000
opt.backup = false
opt.writebackup = false
opt.swapfile = false
opt.updatetime = 250
opt.timeoutlen = 300
opt.ttimeoutlen = 10
opt.redrawtime = 1500
opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "nosplit"
opt.confirm = true
opt.mouse = "a"
opt.completeopt = { "menu", "menuone", "noinsert", "noselect" }

-- Diagnostics: inline only, no floating windows.
vim.diagnostic.config({
  virtual_text = false,
  virtual_lines = false,
  signs = { text = { "\u{f057}", "\u{f071}", "\u{f05a}", "\u{f0eb}" } },
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = false,
})

local has_clipboard_get = vim.fn.executable("termux-clipboard-get") == 1
local has_clipboard_set = vim.fn.executable("termux-clipboard-set") == 1
if has_clipboard_get and has_clipboard_set then
  local function copy(lines)
    vim.fn.system({ "termux-clipboard-set", table.concat(lines, "\n") })
    return vim.v.shell_error == 0 and 0 or 1
  end
  local function paste()
    return { vim.fn.systemlist({ "termux-clipboard-get" }), "v" }
  end
  vim.g.clipboard = {
    name = "termux",
    copy = { ["+"] = copy, ["*"] = copy },
    paste = { ["+"] = paste, ["*"] = paste },
  }
  opt.clipboard = "unnamedplus"
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp" },
  callback = function()
    if vim.bo.commentstring == "" then
      vim.bo.commentstring = "// %s"
    end
  end,
})

-- Never let a stray netrw instance fight the file explorer.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
