return {
  {
    "saghen/blink.cmp",
    version = "1.*",
    opts = {
      keymap = {
        preset = "none",
        ["<Tab>"] = { "select_next", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },
        ["<CR>"] = { "accept", "fallback" },
        ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide" },
      },

      appearance = {
        nerd_font_variant = "mono",
      },

      completion = {
        menu = {
          auto_show = true,
          border = "rounded",
          max_height = 8,
        },
        list = {
          selection = {
            preselect = false,
            auto_insert = false,
          },
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 250,
          window = {
            border = "rounded",
          },
        },
        -- Tắt chữ preview để giao diện gọn hơn trên màn hình điện thoại.
        ghost_text = {
          enabled = false,
        },
      },

      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
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
