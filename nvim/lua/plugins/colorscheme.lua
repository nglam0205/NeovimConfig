return {
    {
        "craftzdog/solarized-osaka.nvim",
        lazy = false,
        priority = 1000,

        opts = {
            style = "",
            transparent = false,
            terminal_colors = true,

            styles = {
                comments = { italic = true },
                keywords = { italic = false },
                functions = {},
                variables = {},
                sidebars = "dark",
                floats = "dark",
            },

            sidebars = {
                "qf",
                "help",
                "terminal",
            },

            dim_inactive = false,
            lualine_bold = true,
        },

        config = function(_, opts)
            require("solarized-osaka").setup(opts)
            vim.cmd.colorscheme("solarized-osaka")
        end,
    },
}
