-- Native LSP setup: no nvim-lspconfig, no Mason, no extra dependencies.

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true
capabilities.textDocument.completion.completionItem.resolveSupport = {
  properties = { "documentation", "detail", "additionalTextEdits" },
}
capabilities.textDocument.codeAction = capabilities.textDocument.codeAction or {}
capabilities.textDocument.codeAction.resolveSupport = {
  properties = { "edit" },
}

local function borderless(handler_name)
  return function(err, result, ctx, config)
    local handler = vim.lsp.handlers[handler_name]
    return handler(err, result, ctx, vim.tbl_extend("force", config or {}, { border = "none" }))
  end
end

vim.lsp.config("*", {
  capabilities = capabilities,
  handlers = {
    ["textDocument/hover"] = borderless("textDocument/hover"),
    ["textDocument/signatureHelp"] = borderless("textDocument/signatureHelp"),
  },
})

vim.lsp.config("clangd", {
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    "--completion-style=detailed",
    "--header-insertion=iwyu",
    "--pch-storage=memory",
    "--log=error",
    "--enable-config",
  },
  init_options = {
    fallbackFlags = { "-std=c++20" },
  },
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
  root_markers = {
    ".clangd",
    "compile_commands.json",
    "compile_flags.txt",
    "CMakeLists.txt",
    "Makefile",
    ".git",
  },
})

vim.lsp.enable("clangd")

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
  callback = function(event)
    local bufnr = event.buf
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
    end

    map("n", "gd", vim.lsp.buf.definition, "Go to definition")
    map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
    map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
    map("n", "gy", vim.lsp.buf.type_definition, "Go to type definition")
    map("n", "gr", vim.lsp.buf.references, "References")
    map("n", "K", vim.lsp.buf.hover, "Hover documentation")
    map("n", "<C-k>", vim.lsp.buf.signature_help, "Signature help")
    map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
    map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
    map("n", "<leader>f", function()
      vim.lsp.buf.format({ async = true })
    end, "Format buffer")
    map("n", "<leader>d", vim.diagnostic.open_float, "Line diagnostics")
    map("n", "[d", function()
      vim.diagnostic.jump({ count = -1 })
    end, "Previous diagnostic")
    map("n", "]d", function()
      vim.diagnostic.jump({ count = 1 })
    end, "Next diagnostic")

    -- Keep a plain-buffer fallback for environments without blink.cmp.
    vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
  end,
})
