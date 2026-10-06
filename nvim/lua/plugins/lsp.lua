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
                args = {
                    "--style=file",
                },
            },
        },

        format_on_save = {
            timeout_ms = 500,
            lsp_fallback = true,
        },
    },
},  
    {
        "neovim/nvim-lspconfig",

        config = function()
            vim.lsp.config("clangd", {
                cmd = {
                    "/usr/bin/clangd",
                    "--background-index",
                    "--clang-tidy",
                    "--completion-style=detailed",
                    "--header-insertion=iwyu",
                    "--query-driver=/usr/bin/g++",
                },

                filetypes = {
                    "c",
                    "cpp",
                    "objc",
                    "objcpp",
                },

                root_markers = {
                    "compile_commands.json",
                    "compile_flags.txt",
                    ".git",
                },
            })

            vim.lsp.enable("clangd")

            vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(args)
                    local opts = {
                        buffer = args.buf,
                        silent = true,
                    }

                    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
                    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
                    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
                    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)

                    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)

                    vim.keymap.set(
                        "n",
                        "<leader>rn",
                        vim.lsp.buf.rename,
                        opts
                    )

                    vim.keymap.set(
                        "n",
                        "<leader>ca",
                        vim.lsp.buf.code_action,
                        opts
                    )
                end,
            })

            -- Tự động popup khi đứng yên trên code
            vim.api.nvim_create_autocmd("CursorHold", {
                callback = function()
                    local bufnr = vim.api.nvim_get_current_buf()

                    if vim.bo[bufnr].filetype ~= "cpp"
                        and vim.bo[bufnr].filetype ~= "c"
                        and vim.bo[bufnr].filetype ~= "objc"
                        and vim.bo[bufnr].filetype ~= "objcpp" then
                        return
                    end

                    -- Nếu vị trí hiện tại có lỗi/warning
                    local diagnostics = vim.diagnostic.get(
                        bufnr,
                        {
                            lnum = vim.api.nvim_win_get_cursor(0)[1] - 1,
                        }
                    )

                    if #diagnostics > 0 then
                        vim.diagnostic.open_float(0, {
                            scope = "cursor",
                            focus = false,
                            border = "single",
                        })
                        return
                    end

                end,
            })

            -- Độ trễ trước khi popup
            vim.opt.updatetime = 500
        end,
    },

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
                    args = {
                        "--style=file",
                    },
                },
            },

            format_on_save = {
                timeout_ms = 500,
                lsp_fallback = true,
            },
        },
    },
}

