local M = {}

local ns = vim.api.nvim_create_namespace("user.inline_diagnostics")
local diag_severity = vim.diagnostic.severity

local severity = {
  [diag_severity.ERROR] = { icon = "[E]", label = "Error", hl = "DiagnosticError" },
  [diag_severity.WARN] = { icon = "[W]", label = "Warning", hl = "DiagnosticWarn" },
  [diag_severity.INFO] = { icon = "[I]", label = "Info", hl = "DiagnosticInfo" },
  [diag_severity.HINT] = { icon = "[H]", label = "Hint", hl = "DiagnosticHint" },
}
local fallback_severity = severity[diag_severity.INFO]

local state = { buf = nil, win = nil, lnum = nil, width = nil, mark = nil }
local pending = false
local pending_force = false

local function display_width(text)
  return vim.fn.strdisplaywidth(text)
end

local function fit_prefix(prefix, width)
  if display_width(prefix) >= width then
    return ""
  end
  return prefix
end

local function wrap_words(text, width)
  width = math.max(1, width)
  local rows = {}
  local words = {}
  local used = 0

  local function flush()
    if #words > 0 then
      rows[#rows + 1] = table.concat(words, " ")
      words = {}
      used = 0
    end
  end

  local function take(word)
    local out = {}
    local w = 0
    for _, ch in ipairs(vim.fn.split(word, "\\zs")) do
      local cw = display_width(ch)
      if w + cw > width and #out > 0 then
        break
      end
      out[#out + 1] = ch
      w = w + cw
      if w >= width then
        break
      end
    end
    return table.concat(out), w
  end

  for word in text:gmatch("%S+") do
    while display_width(word) > width do
      flush()
      local head = take(word)
      if head == "" then
        break
      end
      rows[#rows + 1] = head
      word = word:sub(#head + 1)
    end
    if word ~= "" then
      local ww = display_width(word)
      if #words == 0 then
        words[1] = word
        used = ww
      elseif used + 1 + ww <= width then
        words[#words + 1] = word
        used = used + 1 + ww
      else
        flush()
        words[1] = word
        used = ww
      end
    end
  end

  flush()
  if #rows == 0 then
    rows[1] = ""
  end
  return rows
end

local function normalize(text)
  text = tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
  local lines = {}
  for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
    line = line:gsub("\t", "    "):gsub("%s+$", "")
    if line ~= "" then
      lines[#lines + 1] = line
    end
  end
  if #lines == 0 then
    lines[1] = ""
  end
  return lines
end

local function push_wrapped(rows, text, width, first_prefix, next_prefix, hl)
  first_prefix = fit_prefix(first_prefix, width)
  next_prefix = fit_prefix(next_prefix, width)
  local prefix_width = math.max(display_width(first_prefix), display_width(next_prefix))
  for i, line in ipairs(wrap_words(text, width - prefix_width)) do
    local prefix = i == 1 and first_prefix or next_prefix
    rows[#rows + 1] = {
      { prefix, hl },
      { line, hl },
    }
  end
end

local function push_message(rows, lines, width, sev)
  local prefix = sev.icon .. " " .. sev.label .. ": "
  if display_width(prefix) >= width then
    prefix = sev.icon .. " "
  end
  prefix = fit_prefix(prefix, width)
  local next_prefix = string.rep(" ", display_width(prefix))
  local body_width = math.max(1, width - display_width(prefix))
  local first = true

  for _, line in ipairs(lines) do
    for _, wrapped in ipairs(wrap_words(line, body_width)) do
      if first then
        rows[#rows + 1] = {
          { prefix, sev.hl },
          { wrapped, "Normal" },
        }
        first = false
      else
        rows[#rows + 1] = {
          { next_prefix, "Normal" },
          { wrapped, "Normal" },
        }
      end
    end
  end
end

local function raw_lsp(diagnostic)
  local data = diagnostic.user_data
  if type(data) == "table" and type(data.lsp) == "table" then
    return data.lsp
  end
  return {}
end

local function related_information(diagnostic)
  local related = diagnostic.relatedInformation
  if type(related) ~= "table" or #related == 0 then
    related = raw_lsp(diagnostic).relatedInformation
  end
  if type(related) == "table" then
    return related
  end
  return {}
end

local function related_location(related)
  local location = related.location
  if type(location) ~= "table" or type(location.uri) ~= "string" then
    return nil
  end
  local ok, path = pcall(vim.uri_to_fname, location.uri)
  if not ok or not path then
    return nil
  end
  local start = location.range and location.range.start
  local name = vim.fn.fnamemodify(path, ":t")
  if start and start.line then
    return string.format("%s:%d:%d", name, start.line + 1, (start.character or 0) + 1)
  end
  return name
end

local function build_rows(diagnostics, width)
  local rows = {}
  local seen = {}
  local seen_related = {}

  for _, diagnostic in ipairs(diagnostics) do
    local key = table.concat({
      diagnostic.lnum or 0,
      diagnostic.col or 0,
      diagnostic.severity or 0,
      diagnostic.message or "",
    }, "\0")

    if not seen[key] then
      seen[key] = true
      local sev = severity[diagnostic.severity] or fallback_severity
      push_message(rows, normalize(diagnostic.message), width, sev)

      local raw = raw_lsp(diagnostic)
      local source = diagnostic.source or raw.source
      local code = diagnostic.code
      if code == nil then
        code = raw.code
      end

      local meta = {}
      if type(source) == "string" and source ~= "" then
        meta[#meta + 1] = source
      end
      if code ~= nil and tostring(code) ~= "" then
        meta[#meta + 1] = "code " .. tostring(code)
      end
      if #meta > 0 then
        push_wrapped(rows, table.concat(meta, " · "), width, "    ", "    ", "Comment")
      end

      for _, related in ipairs(related_information(diagnostic)) do
        local message = tostring(related.message or "")
        if message ~= "" then
          local location = related_location(related)
          local text = location and (location .. "  " .. message) or message
          if not seen_related[text] then
            seen_related[text] = true
            push_wrapped(rows, text, width, "    ↳ ", "      ", "Comment")
          end
        end
      end
    end
  end

  return rows
end

local function clear_mark()
  if state.mark and state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    pcall(vim.api.nvim_buf_del_extmark, state.buf, ns, state.mark)
  end
  state.mark = nil
  state.buf = nil
  state.win = nil
  state.lnum = nil
  state.width = nil
end

local function render(force)
  local win = vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) then
    clear_mark()
    return
  end

  local buf = vim.api.nvim_win_get_buf(win)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
    clear_mark()
    return
  end

  local lnum = vim.api.nvim_win_get_cursor(win)[1] - 1
  local width = math.max(8, vim.api.nvim_win_get_width(win) - 1)
  if not force and state.buf == buf and state.win == win and state.lnum == lnum and state.width == width and state.mark then
    return
  end

  clear_mark()

  local diagnostics = vim.diagnostic.get(buf, { lnum = lnum })
  if #diagnostics == 0 then
    return
  end

  table.sort(diagnostics, function(a, b)
    if a.severity ~= b.severity then
      return a.severity < b.severity
    end
    if a.col ~= b.col then
      return a.col < b.col
    end
    return (a.message or "") < (b.message or "")
  end)

  local rows = build_rows(diagnostics, width)
  if #rows == 0 then
    return
  end

  state.mark = vim.api.nvim_buf_set_extmark(buf, ns, lnum, 0, {
    virt_lines = rows,
    virt_lines_leftcol = true,
    virt_lines_overflow = "trunc",
  })
  state.buf = buf
  state.win = win
  state.lnum = lnum
  state.width = width
end

local function schedule_refresh(force)
  if force then
    pending_force = true
  end
  if pending then
    return
  end
  pending = true
  vim.schedule(function()
    pending = false
    local force_now = pending_force
    pending_force = false
    pcall(render, force_now)
  end)
end

function M.refresh()
  schedule_refresh(true)
end

local group = vim.api.nvim_create_augroup("UserInlineDiagnostics", { clear = true })

vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
  group = group,
  callback = function()
    schedule_refresh(false)
  end,
})

vim.api.nvim_create_autocmd({
  "BufEnter",
  "BufWinEnter",
  "WinEnter",
  "WinClosed",
  "WinResized",
  "VimResized",
  "InsertLeave",
}, {
  group = group,
  callback = function()
    schedule_refresh(true)
  end,
})

vim.api.nvim_create_autocmd("DiagnosticChanged", {
  group = group,
  callback = function(event)
    if event.buf == vim.api.nvim_get_current_buf() then
      schedule_refresh(true)
    end
  end,
})

vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout", "BufUnload" }, {
  group = group,
  callback = function(event)
    if state.buf == event.buf then
      clear_mark()
    end
  end,
})

schedule_refresh(true)

return M
