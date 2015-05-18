-- require "common"
-- util.add_path("./pj/scene/?.lua")
-- util.add_path("./pj/protocol/?.lua")
-- require "scene"

local skynet = require "skynet"
local protMgr = nil
local scene = nil
local gated = nil

function init(...)
	require "common"
	util.add_path("./pj/scene/?.lua")
	util.add_path("./pj/protocol/?.lua")
	protMgr = require "protocol_include"
	require "scene"
	local id = ...
	print ("scene server start id:", id)
	id = tonumber(id)
	scene = Scene(id)

-- You can return "queue" for queue service mode
	return "queue"
end

function exit(...)
	print ("scene server exit:", ...)
	scene = nil
end

function __send_client(roleId, buf, sz )
	if gated == nil then
		gated = skynet.localname(".gated")
	end
	skynet.send(gated, "lua", "sendClient", roleId, buf, sz)
end

local __send_client = __send_client
function _sendClient(roleId, msg, id1, id2)
	assert(type(msg) == "table")
	local buf, sz = protMgr:pack(msg, id1, id2)
	__send_client(roleId, buf, sz )
end

function accept.update(roleId, x, y)
	print("scene update!", roleId)
	scene:update(roleId, x, y)
end

--九宫格内广播
function accept.broadcast9(roleId, msg, id1, id2)
	scene:broadcast9(roleId, msg, id1, id2)
end

function response.error()
	error "throw an error"
end

function response.query(sql)
	print("scene query!", sql)
end


function response.enter(roleId, data)
	print("scene enter!", roleId)
	return scene:enter(roleId, data)
end

-- 不需要
-- function response.leave(roleId)
-- 	print("scene leave!", roleId)
-- 	return scene:leave(roleId)
-- end