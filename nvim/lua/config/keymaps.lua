local map = vim.keymap.set

-- Save
map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save" })

-- Quit
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })

-- Format
map("n", "<leader>f", function()
    vim.lsp.buf.format({
        async = true,
    })
end, { desc = "Format code" })

-- NvimTree
map("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", {
    desc = "Toggle file tree",
})

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Better window navigation
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

-- Move selected lines
map("v", "J", ":m '>+1<CR>gv=gv")
map("v", "K", ":m '<-2<CR>gv=gv")
