local Opt = require("opt")
local Command = require("command")

local Clap = {}

export type Opt = Opt.Opt
export type Command = Command.Command

Clap.Command = Command
Clap.Opt = Opt

return Clap
