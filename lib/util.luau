local String = {}

function String.trim(self: string): string
	return self:gsub("%s+", "")
end

function String.startsWith(self: string, prefix: string)
	return self:find(prefix, 1, true) == 1
end

function assertEq(l, r, msg: string?)
	assert(l == r, msg or `[__CLAP] expected {l} == {r}`)
end

local Lazy = {}
export type Lazy<T> = {
	evaluated: T,
	func: () -> ...any,
} & typeof(Lazy)

function Lazy.new(func: () -> ...any)
	return setmetatable({
		evaluated = nil,
		func = func,
	}, {
		__index = Lazy,
		__call = function<T>(self: Lazy<T>)
			if self.evaluated == nil then
				Lazy.force(self)
			end

			return self.evaluated :: T
		end,
	})
end

function Lazy.force<T>(self: Lazy<T>)
	self.evaluated = self.func()
end

function assertHandler(tbl)
	-- FIXME: Need to type sub as Opt | Command, without circular requires
	-- or separating types into its own module
	for _, sub in tbl do
		if not sub.isParent then
			assertEq(typeof(sub.handler), "function", `[__CLAP] field \`handler\` is mandatory for \`{sub.name}\``)
		end
	end
end

return {
	String = setmetatable(String, {
		__index = string,
	}),

	Lazy = Lazy,

	assertEq = assertEq,
	assertHandler = assertHandler,
}
