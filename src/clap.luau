local Process = require("@lune/process")
local Stdio = require("@lune/stdio")

local Utils = require("../utils/misc")
local assertEq = Utils.AssertEq

local Clap = {}

Clap.Type = "Clap"
Clap.Prototype = {}
Clap.Interface = {}

Clap.Opt = {}
type OptType = "string" | "number" | "bool" | "any"
type OptHandler = () -> string?
type Opt = {
	name: string,
	shortName: string?,
	optType: OptType,
	description: string?,
	handler: OptHandler?,
} & typeof(Clap.Opt)

type FlagArg = {
	name: string,
	isShort: boolean,
	value: string?,
}
type ParsedArgs = {
	flags: { FlagArg }, -- The flags passed to the program
	subcommand: string, -- The subcommand that was invoked
	subcommandArgs: { string }, -- The arguments passed to the subcommand
	subcommandFlags: { FlagArg }, -- The flags passed to the subcommand
}

type OptList = { [string]: (string | number | boolean)? }
type Handler = (args: { string }, opts: OptList) -> string?
type Command = {
	name: string,
	description: string?,
	version: string?,
	subcommandIsRequired: boolean,
	optElseHelp: boolean,
	opts: { Opt },
	author: string?,
	postHelp: string?,
	subcommands: { Command },
	handler: Handler,
} & typeof(Clap.Prototype)

function Clap.Opt.type(self: Opt, type: OptType): Opt
	self.optType = type

	return self
end

function Clap.Opt.handle(self: Opt, handler: OptHandler?): Opt
	self.handler = handler

	return self
end

function Clap.Opt.about(self: Opt, desc: string): Opt
	self.description = desc

	return self
end

function Clap.Opt.new(name: string, shortName: (boolean | string)?)
	local shortSwitch: string? = nil

	if typeof(shortName) == "string" then
		shortSwitch = shortName
	end

	if typeof(shortName) == "boolean" and shortName == true then
		shortSwitch = name:sub(1, 1)
	end

	return setmetatable({
		name = name,
		shortName = shortSwitch,
	}, {
		__index = Clap.Opt,
	})
end

function Clap.Prototype.about(self: Command, desc: string): Command
	self.description = desc

	return self
end

function Clap.Prototype.version(self: Command, ver: string): Command
	self.version = ver

	return self
end

function Clap.Prototype.subcommandRequired(self: Command, isRequired: boolean): Command
	self.subcommandIsRequired = isRequired

	return self
end

function Clap.Prototype.optRequiredElseHelp(self: Command, isRequired: boolean): Command
	self.optElseHelp = isRequired

	return self
end

function Clap.Prototype.afterHelp(self: Command, postHelp: string): Command
	self.postHelp = postHelp

	return self
end

function Clap.Prototype.author(self: Command, author: string): Command
	self.author = author

	return self
end

function Clap.Prototype.subcommand(self: Command, command: Command): Command
	table.insert(self.subcommands, command)

	return self
end

function Clap.Prototype.opt(self: Command, opt: Opt): Command
	table.insert(self.opts, opt)

	return self
end

function __calcPadding(tbl): number
	local paddingMult = 0

	for _, optFmt in tbl do
		if #optFmt[1] > paddingMult then
			paddingMult = #optFmt[1] + 5
		end
	end

	return paddingMult
end

-- tbl:
-- [1] => shortSwitch. longSwitch OR longSwitch
-- [2] => description, variable length
function __leftRightPadding(tbl, padFactor)
	local newTbl = {}

	for idx, val in tbl do
		if #val[1] ~= padFactor then
			newTbl[idx] = val[1] .. (" "):rep(padFactor - #val[1])
		end

		newTbl[idx] ..= val[2] or ""
	end

	return newTbl
end

function Clap.Prototype.showHelp(self: Command)
	print(`{self.name} {if self.description ~= nil then "- " .. self.description else ""}\n`)

	Stdio.write(Stdio.style("bold") .. `\x1B[4;37m` .. "Usage:" .. Stdio.style("reset") .. " " .. Stdio.style("reset"))

	Stdio.write(self.name)

	if #self.opts ~= 0 then
		print(" [OPTIONS]")

		print()
		print(
			Stdio.style("bold")
				.. `\x1B[4;37m`
				.. "Options:"
				.. Stdio.style("reset")
				.. " "
				.. ""
				.. Stdio.style("reset")
		)

		local optsFlagFmt = {}

		for _, optVal: Opt in ipairs(self.opts) do
			local opt = ""

			if optVal.shortName ~= nil then
				opt ..= "-" .. optVal.shortName .. ", "
			end

			opt ..= "--" .. optVal.name

			table.insert(optsFlagFmt, { opt, optVal.description })
		end

		local formattedOpts = __leftRightPadding(optsFlagFmt, __calcPadding(optsFlagFmt))

		print(table.concat(formattedOpts, "\n"))
		print()
	end

	if #self.subcommands ~= 0 then
		print(Stdio.style("bold") .. `\x1B[4;37m` .. "Commands:" .. Stdio.style("reset") .. " " .. Stdio.style("reset"))

		local subcommandNamesFmt = {}

		for _, subcommand: Command in ipairs(self.subcommands) do
			table.insert(subcommandNamesFmt, { subcommand.name, subcommand.description or "" })
		end

		local formattedSubcommands = __leftRightPadding(subcommandNamesFmt, __calcPadding(subcommandNamesFmt))

		print(table.concat(formattedSubcommands, "\n") .. "\n")
	else
		print()
	end

	Stdio.write(self.postHelp .. "\n" or "")
end

function Clap.Prototype.onRun(self: Command, handler: Handler): Command
	self.handler = handler

	return self
end

function __help(self)
	return function()
		self:showHelp()
	end
end

function __version(self)
	return function()
		print(string.format("%s %s", self.name, self.version))
	end
end

function __handleFlags(self: Command, flags: { FlagArg })
	for _, flag in flags do
		-- FIXME: This is bad
		for _, opt: Opt in ipairs(self.opts) do
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

function __run(self: Command, args: ParsedArgs)
	-- First handle the global flags
	__handleFlags(self, args.flags)

	-- Then discover a handler and opts for the subcommand
	local subcommand
	for _, command: Command in ipairs(self.subcommands) do
		if command.name == args.subcommand then
			subcommand = command
		end
	end

	if subcommand == nil or subcommand.handler == nil then
		self:showHelp()
		Process.exit()
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
							Stdio.style("bold")
								.. Stdio.color("red")
								.. "error: "
								.. Stdio.color("reset")
								.. `expected argument {opt.name} of type '{Stdio.color("yellow") .. opt.optType .. Stdio.color(
									"reset"
								)}'`
						)
						Process.exit(1)
					end
				end

				opts[flag.name] = flag.value
				flagDefined = true
				break
			end
		end

		if not flagDefined then
			print(
				Stdio.style("bold")
					.. Stdio.color("red")
					.. "error: "
					.. Stdio.color("reset")
					.. `got unexpected option '{Stdio.color("yellow") .. flag.name .. Stdio.color("reset")}'`
			)
			Process.exit(1)
		end
	end

	-- Finally execute the handler for the subcommand
	subcommand.handler(args.subcommandArgs, opts)
end

-- Luau generics SUCK, so we can't take a generic and need to use a union instead
function __assertHandler(tbl)
	for _, sub: Opt | Command in tbl do
		if not sub.isParent then
			assertEq(typeof(sub.handler), "function", `[__CLAP] field \`handler\` is mandatory for \`{sub.name}\``)
		end
	end
end

function Clap.Prototype.run(self: Command)
	if self.optElseHelp == nil then
		self.optElseHelp = false
	end

	if self.subcommandIsRequired == nil then
		self.subcommandIsRequired = true
	end

	if #self.subcommands ~= 0 and #self.opts ~= 0 then
		__assertHandler(self.subcommands)
		__assertHandler(self.opts)
	end

	assertEq(typeof(self.name), "string", "[__CLAP] field `name` is mandatory!")

	local args = table.clone(Process.args)

	local builtins: {
		[string]: {
			aliases: { string },
			-- FIXME: not any pls
			implementation: (any) -> string,
		},
	} =
		{
			help = {
				aliases = { "-h", "--help", "help" },
				implementation = __help(self),
			},
			version = {
				aliases = { "-v", "--version", "version" },
				implementation = __version(self),
			},
		}

	for _, builtin in builtins do
		for _, alias in builtin.aliases do
			if table.find(args, alias) then
				builtin.implementation(self)
				Process.exit()
			end
		end
	end

	-- TODO: Iterate and form it into a structure
	local parsedArgs: ParsedArgs = {
		flags = {},
		subcommand = nil,
		subcommandArgs = {},
		subcommandFlags = {},
	}

	local nextIsSubcommandFlagValue = false
	for pos, arg in args do
		-- FIXME: Numbers should work for args
		local optName, isShort = table.pack(string.match(arg, "-+(%a+)"))[1], #arg == 2

		-- Argument was not an opt, try subcommand
		if optName == nil then
			if parsedArgs.subcommand == nil then
				parsedArgs.subcommand = arg
			elseif nextIsSubcommandFlagValue then
				nextIsSubcommandFlagValue = false
				parsedArgs.subcommandFlags[#parsedArgs.subcommandFlags].value = arg
			else
				table.insert(parsedArgs.subcommandArgs, arg)
			end

			continue
		end

		-- If this is after a subcommand arg was found, then we look for
		-- a flag value, global flags cannot take arguments. Perhaps reconsider
		-- in future?
		local flagList
		if parsedArgs.subcommand then
			flagList = parsedArgs.subcommandFlags
			nextIsSubcommandFlagValue = true
		else
			flagList = parsedArgs.flags
		end

		table.insert(flagList, {
			name = optName,
			value = nil,
			isShort = isShort,
		})
	end

	__run(self, parsedArgs)
end

-- isRoot: whether the Command is the main CLI, or a subcommand
function Clap.Interface.new(name: string, isRoot: boolean?)
	return setmetatable({
		isParent = isRoot or false,
		name = name,
		subcommands = {},
		opts = {},
	}, {
		__index = Clap.Prototype,
		__tostring = function(self: Command)
			return string.format("%s<%s>", Clap.Type, self.name)
		end,
	})
end

function Clap.Interface.command(name: string, isRoot: boolean?)
	return Clap.Interface.new(name, isRoot or false)
end

return {
	Command = Clap.Interface,
	Opt = Clap.Opt,
}
