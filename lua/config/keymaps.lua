local map = vim.keymap.set

-- File explorer.
map("n", "<Space>e", "<cmd>NvimTreeToggle<cr>", { desc = "Toggle file explorer", silent = true })
map("n", "<Space>E", "<cmd>NvimTreeFocus<cr>", { desc = "Focus file explorer", silent = true })

-- Quality-of-life.
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
map("n", "<leader>w", "<cmd>write<cr>", { desc = "Save file", silent = true })
map("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit window", silent = true })
map("n", "<leader>h", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight", silent = true })

-- Buffers as tabs.
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer", silent = true })
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer", silent = true })
map("n", "<leader>x", "<cmd>bdelete<cr>", { desc = "Close buffer", silent = true })

-- Move lines in visual mode.
map("v", "J", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })
map("n", "<leader>j", ":m .+1<cr>==", { desc = "Move line down", silent = true })
map("n", "<leader>k", ":m .-2<cr>==", { desc = "Move line up", silent = true })

-- Comments and editing.
map("n", "<leader>/", "gcc", { remap = true, desc = "Toggle comment" })
map("x", "<leader>/", "gc", { remap = true, desc = "Toggle comment" })
map({ "n", "x" }, "<leader>D", function()
  if vim.fn.mode() ~= "n" then
    local first = vim.fn.line("'<")
    local last = vim.fn.line("'>")
    vim.api.nvim_buf_set_lines(0, last, last, false, vim.api.nvim_buf_get_lines(0, first - 1, last, false))
  else
    local row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, row, row, false, vim.api.nvim_buf_get_lines(0, row - 1, row, false))
  end
end, { desc = "Duplicate line or selection" })
map("n", "<leader>sw", "*", { desc = "Search word under cursor" })
map("n", "<leader>sr", ":%s/\\<<C-r><C-w>\\>//gI<Left><Left><Left>", { desc = "Replace word in file" })
