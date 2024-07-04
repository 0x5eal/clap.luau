local clap = require("../lib")

local Command = clap.Command
local Opt = clap.Opt

Command.new("hello_cli", true)
	:about("A simple CLI to print greeting messages")
	:version("0.1.0")
	:subcommandRequired(true)
	:optRequiredElseHelp(true)
	:afterHelp("You saw the help menu before me ^^")
	:author("Me <me@self.com>")
	:subcommand(Command.new("hello")
		:about("some command!")
		:onRun(function(args, options)
			local count = tonumber(options.count) or 1
			for i = 1, count do
				print("Hello", args[1] or "world")
			end
		end)
		:opt(Opt.new("count", true):type("number"):about("how many times to say hello")))
	:run()
