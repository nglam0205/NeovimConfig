local M = {}

local exts = { cpp = true, cc = true, cxx = true }

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "CP" })
end

local function source()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    notify("Save the buffer before building.", vim.log.levels.WARN)
    return nil
  end
  local src = vim.fn.fnamemodify(name, ":p")
  local ext = vim.fn.fnamemodify(src, ":e"):lower()
  if not exts[ext] then
    notify("CP workflow supports .cpp, .cc and .cxx files.", vim.log.levels.WARN)
    return nil
  end
  return src
end

local function paths(src)
  local base = vim.fn.fnamemodify(src, ":p:r")
  local exe = base
  if exe == src then
    exe = base .. ".out"
  end
  return {
    src = src,
    exe = exe,
    inp = base .. ".INP",
    out = base .. ".OUT",
    tmp = exe .. ".tmp",
    dir = vim.fn.fnamemodify(src, ":p:h"),
  }
end

local function show_errors(output)
  local lines = vim.split(output, "\n", { trimempty = true })
  vim.fn.setqflist({}, "r", { title = "g++", lines = lines })
  if #lines > 0 then
    pcall(vim.cmd, "copen")
  end
end

function M.build(force)
  local src = source()
  if not src then
    return false
  end
  if vim.fn.executable("g++") ~= 1 then
    notify("g++ was not found in PATH.", vim.log.levels.ERROR)
    return false
  end
  if vim.api.nvim_get_option_value("modified", { buf = 0 }) then
    local ok = pcall(vim.cmd, "silent write")
    if not ok then
      notify("Could not save the buffer.", vim.log.levels.ERROR)
      return false
    end
  end

  local p = paths(src)
  local src_stat = vim.uv.fs_stat(p.src)
  local exe_stat = vim.uv.fs_stat(p.exe)
  if not force and exe_stat and src_stat and exe_stat.mtime.sec > src_stat.mtime.sec then
    return true
  end

  pcall(vim.uv.fs_unlink, p.tmp)
  local flags = vim.g.cpp_flags or { "-std=c++20", "-O2", "-pipe" }
  local cmd = { "g++" }
  vim.list_extend(cmd, flags)
  vim.list_extend(cmd, { p.src, "-o", p.tmp })

  local output = vim.fn.system(cmd)
  local code = vim.v.shell_error
  if code ~= 0 then
    pcall(vim.uv.fs_unlink, p.tmp)
    show_errors(output)
    notify("Build failed.", vim.log.levels.ERROR)
    return false
  end

  local ok, err = vim.uv.fs_rename(p.tmp, p.exe)
  if not ok then
    pcall(vim.uv.fs_unlink, p.tmp)
    notify("Could not replace executable: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  if output ~= "" then
    vim.fn.setqflist({}, "r", { title = "g++", lines = vim.split(output, "\n", { trimempty = true }) })
  end
  notify("Build OK: " .. vim.fn.fnamemodify(p.exe, ":t"))
  return true
end

function M.run()
  local src = source()
  if not src then
    return
  end
  if not M.build(false) then
    return
  end

  local p = paths(src)
  if vim.fn.executable(p.exe) ~= 1 then
    notify("Executable is missing: " .. p.exe, vim.log.levels.ERROR)
    return
  end

  local shell = vim.fn.executable("bash") == 1 and "bash" or vim.o.shell
  local command = "cd " .. vim.fn.shellescape(p.dir) .. " && " .. vim.fn.shellescape(p.exe)
  if vim.fn.filereadable(p.inp) == 1 then
    command = command .. " < " .. vim.fn.shellescape(p.inp)
  end
  command = command .. "; printf '\\n[exit %d]\\n' $?"

  vim.cmd("botright split")
  vim.fn.termopen({ shell, "-lc", command }, { cwd = p.dir })
  pcall(vim.cmd, "startinsert")
end

function M.open_input()
  local src = source()
  if not src then
    return
  end
  local p = paths(src)
  vim.cmd("vsplit " .. vim.fn.fnameescape(p.inp))
end

function M.open_output()
  local src = source()
  if not src then
    return
  end
  local p = paths(src)
  if vim.fn.filereadable(p.out) ~= 1 then
    notify("No output file yet: " .. p.out, vim.log.levels.WARN)
    return
  end
  vim.cmd("vsplit " .. vim.fn.fnameescape(p.out))
end

vim.api.nvim_create_user_command("CPBuild", function() M.build(false) end, {})
vim.api.nvim_create_user_command("CPRebuild", function() M.build(true) end, {})
vim.api.nvim_create_user_command("CPRun", M.run, {})
vim.api.nvim_create_user_command("CPInput", M.open_input, {})
vim.api.nvim_create_user_command("CPOutput", M.open_output, {})

vim.keymap.set("n", "<leader>b", function() M.build(false) end, { desc = "Build current C++ file", silent = true })
vim.keymap.set("n", "<leader>R", function() M.build(true) end, { desc = "Rebuild current C++ file", silent = true })
vim.keymap.set("n", "<leader>r", M.run, { desc = "Build and run current C++ file", silent = true })
vim.keymap.set("n", "<leader>i", M.open_input, { desc = "Open input file", silent = true })
vim.keymap.set("n", "<leader>o", M.open_output, { desc = "Open output file", silent = true })

return M
