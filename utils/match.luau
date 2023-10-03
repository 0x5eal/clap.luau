-- Recreation of `match` in Rust
local match = function<R>(val, arms: { [any]: any }): R?
	if arms[val] ~= nil then
		if typeof(arms[val]) == "function" then
			return arms[val]()
		else
			return arms[val]
		end
	elseif arms["_"] then
		if typeof(arms["_"]) == "function" then
			return arms["_"](val)
		else
			return arms["_"]
		end
	else
		error("non exhuastive pattern detected!")
	end
end

return match
