local Process = require("@lune/process")
local Stdio = require("@lune/stdio")

local match = require("../utils/match")
local Utils = require("../utils/misc")
local assertEq = Utils.AssertEq
local trim = Utils.StringTrim

local Clap = {}

Clap.Type = "Clap"
Clap.Prototype = {}
Clap.Interface = {}

Clap.Opt = {}
type ClapOptType = "string" | "number" | "bool" | "any"
type ClapOpt = { name: string, shortName: string?, type: ClapOptType, description: string? } & typeof(Clap.Opt)

function Clap.Opt.type(self: ClapOpt, type: ClapOptType): ClapOpt
	self.type = type

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

function Clap.Prototype.run(self: ClapProto)
	if self.OptElseHelp == nil then
		self.OptElseHelp = false
	end

	if self.subcommandIsRequired == nil then
		self.subcommandIsRequired = true
	end

	if #self.subcommands ~= 0 then
		for _, subcommand: ClapProto in ipairs(self.subcommands) do
			if not subcommand.isParent then
				assertEq(
					typeof(subcommand.handler),
					"function",
					`[__CLAP] field \`handler\` is mandatory for subcommand \`{subcommand.name}\``
				)
			end
		end
	end

	assertEq(typeof(self.name), "string", "[__CLAP] field `name` is mandatory!")
	-- make sure every subcommand has an onRun

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

			if not commandExists and self.optElseHelp then
				self:showHelp()
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
