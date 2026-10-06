return {
    {
        "saghen/blink.cmp",
        version = "1.*",

        opts = {
            keymap = {
                preset = "none",

                -- Completion tiếp theo
                ["<Tab>"] = {
                    "select_next",
                    "fallback",
                },

                ["<Down>"] = {
                    "select_next",
                    "fallback",
                },

                -- Completion trước
                ["<S-Tab>"] = {
                    "select_prev",
                    "fallback",
                },

                ["<Up>"] = {
                    "select_prev",
                    "fallback",
                },

                -- Accept
                ["<CR>"] = {
                    "accept",
                    "fallback",
                },

                -- Mở completion
                ["<C-Space>"] = {
                    "show",
                    "show_documentation",
                    "hide_documentation",
                },

                -- Đóng completion
                ["<C-e>"] = {
                    "hide",
                },
            },

            appearance = {
                nerd_font_variant = "mono",
            },

            completion = {
                menu = {
                    auto_show = true
                },
                list = {
                  selection = {
                    preselect = false
                  }
                },
                documentation = {
                    auto_show = true,
                    auto_show_delay_ms = 200,
                },

                -- Preview lựa chọn ngay dưới con trỏ
                ghost_text = {
                    enabled = true,
                },
            },

            sources = {
                default = {
                    "lsp",
                    "path",
                    "snippets",
                    "buffer",
                },
            },

            snippets = {
                preset = "luasnip",
            },
        },
    },

    {
        "L3MON4D3/LuaSnip",
        version = "v2.*",

        config = function()
            require("luasnip.loaders.from_lua").lazy_load({
                paths = vim.fn.stdpath("config") .. "/snippets",
            })
        end,
    },
} 
