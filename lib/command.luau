local stdio = require("@lune/stdio")
local process = require("@lune/process")

local Opt = require("opt")
type Opt = Opt.Opt

local interface = require("interface")
local types = require("types")
local util = require("util")
local builtins = require("builtins")

local parser = require("parser")
type ParsedArgs = parser.ParsedArgs

local String = util.String
local Lazy = util.Lazy

local Command = {}
Command.Type = "Command"
Command.Prototype = {}
Command.Interface = {}

export type CommandHandler = types.CommandHandler
export type Command = types.Command & typeof(Command.Prototype)

function Command.Prototype.about(self: Command, desc: string): Command
	self.description = desc

	return self
end

function Command.Prototype.version(self: Command, ver: string): Command
	self.versionNum = ver
	self.builtins.version = Lazy.new(function()
		return builtins.version.create(self)
	end)

	return self
end

function Command.Prototype.subcommandRequired(self: Command, isRequired: boolean): Command
	self.subcommandIsRequired = isRequired

	return self
end

function Command.Prototype.optRequiredElseHelp(self: Command, isRequired: boolean): Command
	self.optElseHelp = isRequired

	return self
end

function Command.Prototype.afterHelp(self: Command, postHelp: string): Command
	self.postHelp = postHelp

	return self
end

function Command.Prototype.author(self: Command, author: string): Command
	self.authorName = author

	return self
end

function Command.Prototype.subcommand(self: Command, command: Command): Command
	table.insert(self.subcommands, command)

	return self
end

function Command.Prototype.onRun(self: Command, handler: CommandHandler): Command
	self.handler = handler

	return self
end

function Command.Prototype.opt(self: Command, opt: Opt): Command
	table.insert(self.opts, opt)

	return self
end

-- FIXME: This seems to be totally broken right now
function Command.Prototype.showHelp(self: Command)
	print(`{self.name} {if self.description ~= nil then "- " .. self.description else ""}\n`)

	stdio.write(stdio.style("bold") .. `\x1B[4;37m` .. "Usage:" .. stdio.style("reset") .. " " .. stdio.style("reset"))

	stdio.write(self.name)

	if #self.opts ~= 0 then
		print(" [OPTIONS]")

		print()
		print(
			stdio.style("bold")
				.. `\x1B[4;37m`
				.. "Options:"
				.. stdio.style("reset")
				.. " "
				.. ""
				.. stdio.style("reset")
		)

		local optsFlagFmt = {}

		for _, optVal in ipairs(self.opts) do
			local opt = ""

			if optVal.shortName ~= nil then
				opt ..= "-" .. optVal.shortName .. ", "
			end

			opt ..= "--" .. optVal.name

			table.insert(optsFlagFmt, { opt, optVal.description })
		end

		local formattedOpts = interface.leftRightPadding(optsFlagFmt, interface.calcPadding(optsFlagFmt))

		print(table.concat(formattedOpts, "\n"))
		print()
	end

	if #self.subcommands ~= 0 then
		print(stdio.style("bold") .. `\x1B[4;37m` .. "Commands:" .. stdio.style("reset") .. " " .. stdio.style("reset"))

		local subcommandNamesFmt = {}

		for _, subcommand: Command in ipairs(self.subcommands) do
			table.insert(subcommandNamesFmt, { subcommand.name, subcommand.description or "" })
		end

		local formattedSubcommands =
			interface.leftRightPadding(subcommandNamesFmt, interface.calcPadding(subcommandNamesFmt))

		print(table.concat(formattedSubcommands, "\n") .. "\n")
	else
		print()
	end

	stdio.write(self.postHelp .. "\n" or "")
end

function Command.Prototype.run(self: Command)
	self.builtins.help = Lazy.new(function()
		return builtins.help.create(self)
	end)

	if self.optElseHelp == nil then
		self.optElseHelp = false
	end

	if self.subcommandIsRequired == nil then
		self.subcommandIsRequired = true
	end

	if #self.subcommands ~= 0 then
		util.assertHandler(self.subcommands)
	end

	util.assertEq(typeof(self.name), "string", "[__CLAP] field `name` is mandatory!")

	local args = table.clone(process.args)

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
				implementation = self.builtins.help(),
			},
			version = {
				aliases = { "-v", "--version", "version" },
				implementation = self.builtins.version(),
			},
		}

	for _, builtin in builtins do
		for _, alias in builtin.aliases do
			if table.find(args, alias) then
				builtin.implementation(self)
				process.exit()
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
		local optName, isShort = table.pack(String.match(arg, "-+(%a+)"))[1], #arg == 2

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

	-- FIXME: Args aren't parsed correctly and don't work for show
	parser.invokeEntrypoint(self, parsedArgs)
end

-- isRoot: whether the Command is the main CLI, or a subcommand
function Command.Interface.new(name: string, isRoot: boolean?)
	return setmetatable({
		isParent = isRoot or false,
		name = name,
		subcommands = {},
		opts = {},
		builtins = {},
	}, {
		__index = Command.Prototype,
		__type = Command.Type,
		__tostring = function(self: Command)
			return String.format("%s<%s>", Command.Type, self.name)
		end,
	})
end

function Command.Interface.command(name: string, isRoot: boolean?)
	return Command.Interface.new(name, isRoot or false)
end

return Command.Interface
