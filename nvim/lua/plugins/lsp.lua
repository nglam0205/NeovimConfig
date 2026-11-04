return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        c = { "clang_format" },
        cpp = { "clang_format" },
        objc = { "clang_format" },
        objcpp = { "clang_format" },
      },
      formatters = {
        clang_format = {
          command = "clang-format",
          args = { "--style=file" },
        },
      },
      format_on_save = {
        timeout_ms = 1000,
        lsp_fallback = true,
      },
    },
  },

  {
    "neovim/nvim-lspconfig",
    config = function()
      -- Use PATH so this works with Termux packages (clangd), not only /usr/bin.
      vim.lsp.config("clangd", {
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--completion-style=detailed",
          "--header-insertion=iwyu",
        },
        filetypes = { "c", "cpp", "objc", "objcpp" },
        root_markers = { "compile_commands.json", "compile_flags.txt", ".git" },
      })
      vim.lsp.enable("clangd")

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local opts = { buffer = args.buf, silent = true }
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
          vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
          vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
          vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
        end,
      })

      -- Show diagnostics only when the cursor rests on a C/C++ diagnostic.
      vim.api.nvim_create_autocmd("CursorHold", {
        callback = function()
          local bufnr = vim.api.nvim_get_current_buf()
          local ft = vim.bo[bufnr].filetype
          if ft ~= "c" and ft ~= "cpp" and ft ~= "objc" and ft ~= "objcpp" then
            return
          end

          local row = vim.api.nvim_win_get_cursor(0)[1] - 1
          if #vim.diagnostic.get(bufnr, { lnum = row }) > 0 then
            vim.diagnostic.open_float(bufnr, {
              scope = "cursor",
              focus = false,
              border = "rounded",
            })
          end
        end,
      })
    end,
  },
}
