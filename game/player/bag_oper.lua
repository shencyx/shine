--require ""

local protMgr = protMgr
local player = g_player

--test 
-- protMgr:registFunc(2, 1, function( msg )
-- 	print_r(msg)
-- 	local ret = {
--         ["type"] = 223,
--         ["id"] = 101,
--         ["name"] = "物品",
-- 	}
-- 	player:sendClient(ret, "bag", "Item")
-- 	--return ret, "bag", "Item"
-- end)

local function registBag(id2, func)
	local id1 = 3
	if (type(id2) == "string") then
		id1, id2 = protMgr:getId("bag", id2)
	end
	protMgr:registFunc(id1, id2, func)
end

registBag("GetBag", function( msg )
	print_r(msg)
	local ret = {
        ["type"] = 223,
        ["id"] = 101,
        ["name"] = "物品",
	}
	--player:sendClient(ret, "bag", "Item")
	return ret, "bag", "Item"
end)