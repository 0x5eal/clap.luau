-- local Stdio = require("@lune/stdio")

return {
    StringTrim = function(self: string): string
        return self:gsub("%s+", "")
    end,

    AssertEq = function(l, r, msg: string?)
        assert(l == r, msg or `[__CLAP] expected {l} == {r}`)
    end
}