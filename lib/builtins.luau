local types = require("types")
type Command = types.Command

function makeHelp(
	self: Command & {
		-- FIXME: This is a hack to prevent circular dependencies
		showHelp: (Command) -> (),
	}
)
	return function()
		self:showHelp()
	end
end

function makeVersion(self: Command)
	return function()
		return string.format("%s %s", self.name, self.versionNum or error("unreachable: version is nil"))
	end
end

return {
	help = {
		create = makeHelp,
	},

	version = {
		create = makeVersion,
	},
}
