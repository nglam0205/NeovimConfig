return {
  -- Snippets (loaded only when insert mode starts).
  {
    "L3MON4D3/LuaSnip",
    event = "InsertEnter",
    config = function()
      local ls = require("luasnip")

      ls.config.set_config({
        history = false,
        update_events = "TextChanged,TextChangedI",
        enable_autosnippets = false,
        store_selection_keys = nil,
      })

      ls.add_snippets("cpp", require("snippets.cpp"))
    end,
  },

  -- Fast completion. Rust fuzzy matcher is shipped prebuilt in the plugin.
  {
    "saghen/blink.cmp",
    tag = "v1.10.2", -- v2 requires the separate saghen/blink.lib package.
    event = "InsertEnter",
    dependencies = { "L3MON4D3/LuaSnip" },
    opts = {
      keymap = {
        preset = "super-tab",
        ["<Tab>"] = {
          function(cmp)
            local ls = require("luasnip")
            if ls.expandable() then
              vim.schedule(function() ls.expand_or_jump() end)
              return true
            end
            if ls.jumpable(1) then
              vim.schedule(function() ls.jump(1) end)
              return true
            end
            if cmp.is_visible() then
              return cmp.select_and_accept()
            end
            return false
          end,
          "fallback",
        },
        ["<S-Tab>"] = {
          function(cmp)
            local ls = require("luasnip")
            if ls.jumpable(-1) then
              vim.schedule(function() ls.jump(-1) end)
              return true
            end
            if cmp.is_visible() then
              return cmp.select_prev()
            end
            return false
          end,
          "fallback",
        },
        ["<C-e>"] = { "cancel", "fallback" },
        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-k>"] = { "show_signature", "hide_signature", "fallback" },
      },
      appearance = {
        nerd_font_variant = "mono",
      },
      completion = {
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 300,
          treesitter_highlighting = true,
          window = { border = "none", scrollbar = false },
        },
        ghost_text = { enabled = false },
        menu = {
          border = "none",
          scrollbar = false,
          draw = {
            treesitter = {},
            columns = {
              { "kind_icon", "label", "label_description", gap = 1 },
              { "source_name" },
            },
          },
        },
        list = {
          selection = {
            preselect = false,
            auto_insert = false,
          },
        },
        trigger = {
          show_on_keyword = true,
          show_on_trigger_character = true,
          show_on_insert_on_trigger_character = true,
        },
      },
      signature = {
        enabled = true,
        window = { border = "none", scrollbar = false },
      },
      sources = {
        default = { "lsp", "path", "snippets" },
        providers = {
          snippets = {
            score_offset = 1,
          },
        },
      },
      snippets = { preset = "luasnip" },
      fuzzy = {
        implementation = "prefer_rust_with_warning",
      },
    },
  },
}
