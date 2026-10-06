return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",

        build = ":TSUpdate",

        opts = {
            ensure_installed = {
                "c",
                "cpp",
                "lua",
                "vim",
                "vimdoc",
                "query",
            },

            highlight = {
                enable = true,
            },

            indent = {
                enable = true,
            },
        },
    },
}
