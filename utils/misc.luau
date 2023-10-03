-- local Stdio = require("@lune/stdio")

return {
    StringTrim = function(self: string): string
        return self:gsub("%s+", "")
    end,

    StringStartsWith = function(self: string, prefix: string)
        return self:find(prefix, 1, true) == 1
    end,

    AssertEq = function(l, r, msg: string?)
        assert(l == r, msg or `[__CLAP] expected {l} == {r}`)
    end
}