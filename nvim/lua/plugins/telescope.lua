return {
    {
        "nvim-telescope/telescope.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
        },

        config = function()
            local telescope = require("telescope.builtin")

            vim.keymap.set("n", "<leader>ff",
                telescope.find_files,
                { desc = "Find files" })

            vim.keymap.set("n", "<leader>fg",
                telescope.live_grep,
                { desc = "Live grep" })

            vim.keymap.set("n", "<leader>fb",
                telescope.buffers,
                { desc = "Buffers" })

            vim.keymap.set("n", "<leader>fh",
                telescope.help_tags,
                { desc = "Help" })
        end,
    },
}
