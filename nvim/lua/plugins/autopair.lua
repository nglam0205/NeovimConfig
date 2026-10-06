return {
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",

        opts = {
            check_ts = true,

            ts_config = {
                lua = { "string" },
                javascript = { "template_string" },
            },

            fast_wrap = {
                map = "<M-e>",
                chars = {
                    "{", "[", "(", '"', "'",
                },
                pattern = [=[[%%'%"%w%%%'%w%%'%"%%%%"]]=],
                end_key = "$",
                before_key = "h",
                after_key = "l",
                cursor_move = true,
                keys = "qwertyuiopasdfghjklzxcvbnm",
                manual_position = true,
            },
        },

        config = function(_, opts)
            local npairs = require("nvim-autopairs")
            npairs.setup(opts)
        end,
    },
}
