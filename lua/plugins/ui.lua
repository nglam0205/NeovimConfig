return {
  -- Low-contrast, eye-friendly colors with a warm dark background.
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      compile = true,
      undercurl = true,
      commentStyle = { italic = true },
      functionStyle = {},
      keywordStyle = { italic = true },
      statementStyle = {},
      typeStyle = {},
      transparent = false,
      dimInactive = false,
      terminalColors = true,
      theme = "wave",
      background = { dark = "wave", light = "lotus" },
    },
    config = function(_, opts)
      require("kanagawa").setup(opts)
      vim.cmd.colorscheme("kanagawa")
    end,
  },

  -- One icon provider for the explorer, tabs and statusline.
  {
    "echasnovski/mini.icons",
    lazy = false,
    priority = 900,
    opts = {},
    config = function(_, opts)
      require("mini.icons").setup(opts)
      require("mini.icons").mock_nvim_web_devicons()
    end,
  },

  -- Statusline.
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        theme = "auto",
        globalstatus = true,
        icons_enabled = true,
        section_separators = "",
        component_separators = "",
        disabled_filetypes = { statusline = { "NvimTree" } },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch" },
        lualine_c = { { "filename", path = 1, symbols = { modified = " ●", readonly = "  ", unnamed = "[No Name]" } } },
        lualine_x = { "diagnostics", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
      inactive_sections = {
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "location" },
      },
    },
  },

  -- Tabs (bufferline) with no separator borders.
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        mode = "buffers",
        style_preset = "minimal",
        separators = "",
        show_buffer_close_icons = true,
        show_close_icon = false,
        always_show_bufferline = true,
        indicator = { style = "underline" },
        offsets = {
          {
            filetype = "NvimTree",
            text = "EXPLORER",
            text_align = "left",
            separator = false,
          },
        },
      },
    },
  },

  -- NERDTree-style explorer. Built-in keys: a create, r rename, d delete.
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFocus", "NvimTreeFindFile" },
    keys = {
      { "<Space>e", "<cmd>NvimTreeToggle<cr>", desc = "Toggle file explorer" },
    },
    opts = {
      disable_netrw = true,
      hijack_netrw = true,
      sync_root_with_cwd = true,
      respect_buf_cwd = true,
      view = {
        width = 32,
        side = "left",
        preserve_window_proportions = false,
      },
      renderer = {
        group_empty = true,
        highlight_git = true,
        highlight_opened_files = "none",
        indent_markers = { enable = false },
        icons = {
          show = {
            file = true,
            folder = true,
            folder_arrow = true,
            git = true,
          },
        },
      },
      filters = {
        dotfiles = false,
        git_ignored = false,
      },
      git = { enable = true, timeout = 200 },
      filesystem_watchers = { enable = false },
      update_focused_file = { enable = true, update_root = false },
      actions = {
        open_file = { quit_on_open = true },
      },
      ui = { confirm = { remove = false } },
    },
  },
}
