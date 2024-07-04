local util = require("util")

export type OptType = "string" | "number" | "bool" | "any"
export type OptHandler = () -> string?
export type OptList = { [string]: (string | number | boolean)? }
export type Opt = {
	name: string,
	shortName: string?,
	optType: OptType,
	description: string?,
	handler: OptHandler?,
}

export type CommandHandler = (args: { string }, opts: OptList) -> string?
export type Command = {
	name: string,
	description: string?,
	versionNum: string?,
	subcommandIsRequired: boolean,
	optElseHelp: boolean,
	opts: { Opt },
	authorName: string?,
	postHelp: string?,
	subcommands: { Command },
	handler: CommandHandler,
	builtins: { [string]: util.Lazy<Builtin> },
}

export type Builtin = {
	create: Command,
}

return "<types>"
