local clap = require("clap")

local Command = clap.Command
local Opt = clap.Opt

Command.new("test_cli", true)
	:about("description")
	:version("0.1.0")
	:subcommandRequired(true)
	:optRequiredElseHelp(true)
	:opt(Opt.new("isReal", true))
	:opt(Opt.new("testing", true):about("knock knock?"))
	:opt(Opt.new("grahhh", false):about("really cool option"))
	:afterHelp("You saw the help menu before me ^^")
	:author("Me <me@self.com>")
	:subcommand(Command.new("test"):about("some command!"):onRun(function(args)
		print("Got args: ", args)
	end))
	:subcommand(Command.new("test2"):about("some other command!"):onRun(function(args)
		print("Got args: ", args)
	end))
	:run()
