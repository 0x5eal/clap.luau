local process = require("@lune/process")
local stdio = require("@lune/stdio")

local Opt = require("opt")
type Opt = Opt.Opt
type OptList = Opt.OptList

local Command = require("types")
type Command = Command.Command

export type FlagArg = {
	name: string, -- What the name of the flag is
	isShort: boolean, -- Whether the flag is short or long
	value: string?, -- The value of the flag - only available for flags to subcommands
}
export type ParsedArgs = {
	flags: { FlagArg }, -- The flags passed to the program
	subcommand: string, -- The subcommand that was invoked
	subcommandArgs: { string }, -- The arguments passed to the subcommand
	subcommandFlags: { FlagArg }, -- The flags passed to the subcommand
}

function handleFlags(self: Command, flags: { FlagArg })
	for _, flag in flags do
		-- FIXME: This is bad
		-- FIXME: Add type to opt, currently cyclic dep error
		for _, opt in ipairs(self.opts) do
			if opt.name == flag.name then
				local handler = opt.handler or error("Global options must have a handler")
				local ret = handler(flag.value)

				if ret then
					print(ret)
				end
			end
		end
	end
end

function invokeEntrypoint(
	self: Command & {
		-- FIXME: This is a hack to prevent circular dependencies
		showHelp: (Command) -> (),
	},
	args: ParsedArgs
)
	-- First handle the global flags
	handleFlags(self, args.flags)

	-- Then discover a handler and opts for the subcommand
	local subcommand
	for _, command: Command in ipairs(self.subcommands) do
		if command.name == args.subcommand then
			subcommand = command
		end
	end

	if subcommand == nil or subcommand.handler == nil then
		self:showHelp()
		process.exit()
	end

	local opts: OptList = {}
	for _, flag in args.subcommandFlags do
		local flagDefined = false

		-- FIXME: This is bad too
		for _, opt in ipairs(subcommand.opts) do
			if opt.name == flag.name then
				if opt.optType and opt.optType ~= "any" then
					local isValidType = if opt.optType == "string"
						then true
						elseif opt.optType == "bool" then flag.value == "true"
							or flag.value == "false"
							or flag.value == "0"
							or flag.value == "1"
							or flag.value == ""
						elseif opt.optType == "number" then tonumber(flag.value) ~= nil
						else false

					-- TODO: Cast from string to requested type

					if not isValidType then
						print(
							stdio.style("bold")
								.. stdio.color("red")
								.. "error: "
								.. stdio.color("reset")
								.. `expected argument {opt.name} of type '{stdio.color("yellow") .. opt.optType .. stdio.color(
									"reset"
								)}'`
						)
						process.exit(1)
					end
				end

				opts[flag.name] = flag.value
				flagDefined = true
				break
			end
		end

		if not flagDefined then
			print(
				stdio.style("bold")
					.. stdio.color("red")
					.. "error: "
					.. stdio.color("reset")
					.. `got unexpected option '{stdio.color("yellow") .. flag.name .. stdio.color("reset")}'`
			)
			process.exit(1)
		end
	end

	-- Finally execute the handler for the subcommand
	subcommand.handler(args.subcommandArgs, opts)
end

return {
	handleFlags = handleFlags,
	invokeEntrypoint = invokeEntrypoint,
}
