

local protMgr = protMgr
local player = g_player

local function registBase(id2, func)
	local id1 = 2
	if (type(id2) == "string") then
		id1, id2 = protMgr:getId("base", id2)
	end
	protMgr:registFunc(id1, id2, func)
end

--
registBase(1, function( msg )

	return ret, "", ""
end)