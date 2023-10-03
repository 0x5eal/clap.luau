local Process = require("@lune/process")
local Stdio = require("@lune/stdio")

local match = require("../utils/match")
local Utils = require("../utils/misc")
local assertEq = Utils.AssertEq
local trim = Utils.StringTrim
local startsWith = Utils.StringStartsWith

local Clap = {}

Clap.Type = "Clap"
Clap.Prototype = {}
Clap.Interface = {}

Clap.Opt = {}
type ClapOptType = "string" | "number" | "bool" | "any"
type ClapOpt = {
	name: string,
	shortName: string?,
	type: ClapOptType,
	description: string?,
	handler: ((string | number | boolean | any) -> string?)?,
} & typeof(Clap.Opt)

function Clap.Opt.type(self: ClapOpt, type: ClapOptType): ClapOpt
	self.type = type

	return self
end

function Clap.Opt.handle(self: ClapOpt, handler: ((...any) -> string?)?): ClapOpt
	self.handler = handler

	return self
end

function Clap.Opt.about(self: ClapOpt, desc: string): ClapOpt
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

type ClapProto = {
	name: string,
	description: string?,
	version: string?,
	subcommandIsRequired: boolean,
	optElseHelp: boolean,
	opts: { ClapOpt },
	author: string?,
	postHelp: string?,
	subcommands: ClapProto,
	handler: ((...any) -> string?)?,
} & typeof(Clap.Prototype)

function Clap.Prototype.about(self: ClapProto, desc: string): ClapProto
	self.description = desc

	return self
end

function Clap.Prototype.version(self: ClapProto, ver: string): ClapProto
	self.version = ver

	return self
end

function Clap.Prototype.subcommandRequired(self: ClapProto, isRequired: boolean): ClapProto
	self.subcommandIsRequired = isRequired

	return self
end

function Clap.Prototype.optRequiredElseHelp(self: ClapProto, isRequired: boolean): ClapProto
	self.optElseHelp = isRequired

	return self
end

function Clap.Prototype.afterHelp(self: ClapProto, postHelp: string): ClapProto
	self.postHelp = postHelp

	return self
end

function Clap.Prototype.author(self: ClapProto, author: string): ClapProto
	self.author = author

	return self
end

function Clap.Prototype.subcommand(self: ClapProto, command: ClapProto): ClapProto
	table.insert(self.subcommands, command)

	return self
end

function Clap.Prototype.opt(self: ClapProto, opt: ClapOpt): ClapProto
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

function Clap.Prototype.showHelp(self: ClapProto)
	print(`{self.name} - {self.description or ""}\n`)

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

		for _, optVal: ClapOpt in ipairs(self.opts) do
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

		for _, subcommand: ClapProto in ipairs(self.subcommands) do
			table.insert(subcommandNamesFmt, { subcommand.name, subcommand.description or "" })
		end

		local formattedSubcommands = __leftRightPadding(subcommandNamesFmt, __calcPadding(subcommandNamesFmt))

		print(table.concat(formattedSubcommands, "\n") .. "\n")
	end

	Stdio.write(self.postHelp .. "\n" or "")
end

function Clap.Prototype.onRun(self: ClapProto, handler: (...any) -> string?): ClapProto
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
		print(string.format("%s v%s", self.name, self.version))
	end
end

-- Luau generics SUCK, so we can't take a generic and need to use a union instead
function __assertHandler(tbl)
	for _, sub: ClapOpt | ClapProto in tbl do
		if not sub.isParent then
			assertEq(typeof(sub.handler), "function", `[__CLAP] field \`handler\` is mandatory for \`{sub.name}\``)
		end
	end
end

function __invokeHandler(args, type, handler: ((any | boolean | number | string) -> string?)?)
	local val = trim(args[2]) or ""

	local casted = match(type, {
		string = function()
			return val :: string
		end,
		number = function()
			return val :: number
		end,
		bool = function()
			return val :: boolean
		end,
		any = function()
			return val :: any
		end,

		_ = function()
			return val
		end,
	})

	local handlerNotNil = handler :: (any | boolean | number | string) -> string?
	return handlerNotNil(casted)
end

function Clap.Prototype.run(self: ClapProto)
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

	-- match breaks, if all arms aren't of type function
	match(trim(args[1] or ""), {
		version = __version(self),
		["-v"] = __version(self),
		["--version"] = __version(self),

		help = __help(self),
		["-h"] = __help(self),
		["--help"] = __help(self),

		["_"] = function(cmd: string)
			local commandExists: boolean
			local optExists: boolean

			if #cmd == 2 then
				-- Arg is a switch
				local switch = cmd:match("-(%a)")

				for _, opt: ClapOpt in ipairs(self.opts) do
					if opt.shortName == switch then
						optExists = true

						local ret = __invokeHandler(args, opt.type, opt.handler)

						if ret ~= nil then
							print(ret)
						end

						return
					end
				end
			end

			if #cmd > 2 and startsWith(cmd, "-") then
				-- Arg is a flag
				local flag = cmd:match("--(%a+)")

				for _, opt: ClapOpt in ipairs(self.opts) do
					if opt.name == flag then
						optExists = true

						local ret = __invokeHandler(args, opt.type, opt.handler)

						if ret ~= nil then
							print(ret)
						end

						return
					end
				end
			end

			for _, subCmd: ClapProto in ipairs(self.subcommands) do
				if subCmd.name == cmd then
					commandExists = true
					table.remove(args, 1)

					local ret = (subCmd.handler :: (...any) -> string?)(args)

					if ret ~= nil then
						print(ret)
					end
				end
			end

			local cmdIsEmpty = (cmd == "" or #cmd == 0)

			if cmdIsEmpty and self.optElseHelp then
				self:showHelp()
				return
			end

			if not (commandExists and optExists and cmdIsEmpty) then
				print(
					Stdio.style("bold")
						.. Stdio.color("red")
						.. "error: "
						.. Stdio.color("reset")
						.. `unexpected argument '{Stdio.color("yellow") .. cmd .. Stdio.color("reset")}' found`
						.. "\n"
				)

				-- TODO: include a tip about similar commands available
				self:showHelp()
				Process.exit(1)
			end
		end,
	})
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
		__tostring = function(self: ClapProto)
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
