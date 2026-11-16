local ls = require("luasnip")

local s = ls.snippet
local t = ls.text_node
local f = ls.function_node

local function filename(_, snip)
  local name = snip.env.TM_FILENAME_BASE
  if not name or name == "" then
    return "NAME"
  end
  return name
end

return {
  s("cpp", {
    t({
      "#include <bits/stdc++.h>",
      "",
      "using namespace std;",
      "",
      "int main() {",
      "    freopen(\"",
    }),

    f(filename),

    t({
      ".INP\", \"r\", stdin);",
      "    freopen(\"",
    }),

    f(filename),

    t({
      ".OUT\", \"w\", stdout);",
      "",
      "",
      "    return 0;",
      "}",
    }),
  }),
}
