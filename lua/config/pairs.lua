local map = vim.keymap.set

local pair_map = {
  ["("] = ")",
  ["["] = "]",
  ["{"] = "}",
  ['"'] = '"',
  ["'"] = "'",
}

local closers = {
  [")"] = true,
  ["]"] = true,
  ["}"] = true,
}

local function line_and_col()
  return vim.api.nvim_get_current_line(), vim.api.nvim_win_get_cursor(0)[2]
end

local function next_char()
  local line, col = line_and_col()
  return line:sub(col + 1, col + 1)
end

local function prev_char()
  local line, col = line_and_col()
  return line:sub(col, col)
end

local function in_string_or_comment()
  local p, n = prev_char(), next_char()
  if (p == '"' or p == "'") and n == p then
    return true
  end
  local line = vim.fn.line(".")
  local col = vim.fn.col(".")
  local stack = vim.fn.synstack(line, col)
  for _, id in ipairs(stack) do
    local name = vim.fn.synIDattr(id, "name")
    if name and (name:find("String", 1, true) or name:find("Comment", 1, true) or name:find("Character", 1, true)) then
      return true
    end
  end
  return false
end

local function opener(ch)
  if in_string_or_comment() then
    return ch
  end
  return ch .. pair_map[ch] .. "<Left>"
end

local function closer(ch)
  if next_char() == ch then
    return "<C-g>U<Right>"
  end
  return ch
end

local function quote(ch)
  local nxt = next_char()
  if nxt == ch then
    return "<C-g>U<Right>"
  end
  if in_string_or_comment() then
    return ch
  end
  if nxt ~= "" and nxt:match("[%w_]") then
    return ch
  end
  return ch .. ch .. "<Left>"
end

local function backspace()
  local p, n = prev_char(), next_char()
  if p ~= "" and pair_map[p] and n == pair_map[p] then
    return "<BS><Del>"
  end
  return "<BS>"
end

local function newline()
  local p, n = prev_char(), next_char()
  if not in_string_or_comment() and ((p == "{" and n == "}") or (p == "[" and n == "]") or (p == "(" and n == ")")) then
    return "<CR><Esc>O"
  end
  return "<CR>"
end

local opts = { expr = true, replace_keycodes = true, silent = true }

map("i", "(", function() return opener("(") end, opts)
map("i", "[", function() return opener("[") end, opts)
map("i", "{", function() return opener("{") end, opts)
map("i", '"', function() return quote('"') end, opts)
map("i", "'", function() return quote("'") end, opts)

for ch in pairs(closers) do
  map("i", ch, function() return closer(ch) end, opts)
end

map("i", "<BS>", backspace, opts)
map("i", "<CR>", newline, opts)
