local types = require("types")
local String = require("util").String

local Opt = {}
export type Opt = types.Opt & typeof(Opt)

export type OptList = types.OptList
export type OptType = types.OptType
export type OptHandler = types.OptHandler

function Opt.type(self: Opt, type: OptType): Opt
	self.optType = type

	return self
end

function Opt.handle(self: Opt, handler: OptHandler?): Opt
	self.handler = handler

	return self
end

function Opt.about(self: Opt, desc: string): Opt
	self.description = desc

	return self
end

function Opt.new(name: string, shortName: (boolean | string)?)
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
		__index = Opt,
		__type = Opt,
		__tostring = function(self: Opt)
			return String.format("Opt<%s, %s>", self.name, self.optType)
		end
	})
end

return Opt
