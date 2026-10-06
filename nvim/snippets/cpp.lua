local ls = require("luasnip")

local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

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

        i(1, "NAME"),

        t({
            ".INP\", \"r\", stdin);",
            "    freopen(\"",
        }),

        i(2, "NAME"),

        t({
            ".OUT\", \"w\", stdout);",
            "",
            "",
            "    return 0;",
            "}",
        }),
    }),
}

