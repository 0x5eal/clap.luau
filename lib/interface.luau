function calcPadding(tbl): number
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
function leftRightPadding(tbl, padFactor)
	local newTbl = {}

	for idx, val in tbl do
		if #val[1] ~= padFactor then
			newTbl[idx] = val[1] .. (" "):rep(padFactor - #val[1])
		end

		newTbl[idx] ..= val[2] or ""
	end

	return newTbl
end

return {
	calcPadding = calcPadding,
	leftRightPadding = leftRightPadding,
}
