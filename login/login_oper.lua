-- login_oper.lua
local skynet = require "skynet"
local call = skynet.call
local protMgr = protMgr
local userMgr = g_userMgr
local serverMgr = serverMgr


local tbl = {}

function tbl.Entry(user, msg)
	print_r("==================>>>")
	print_r(user)
	local u = user
	local err, ip, port, token = skynet.call(serverMgr, "lua", "loadRole", u.role.roleId, u.platform, u.area)
	print(err, ip, port, token)
	local ret = {
		err = err,
		ip = "127.0.0.1",
		port = 8888,
		token = "token"
	}
	--player:sendClient(ret, "bag", "Item")
	return ret, "login", "EntryR"
end

function tbl.GetRole(user, msg)
	-- local role = {
	-- 	roleId = 0,
	-- 	name = "name",
	-- 	occ = 1,
	-- 	gender = 1,
	-- 	camp = 1,
	-- 	level = 1,
	-- }
	local role = user.role
	local ret = {}
	ret.err = 0
	ret.roleList = {role}
	return ret, "login", "GetRoleR"
end

function tbl.CreateRole(user, msg)
	local role = {
		roleId = 0,
		name = msg.role.name,
		occ = 1,
		gender = msg.role.gender,
		camp = msg.role.camp,
		level = 1;
	}
	local rmsg = skynet.call(serverMgr, "lua", "createRole", role, user.platform, user.area)
	print("createRole:", rmsg.err, rmsg.roleId)
	role.roleId = rmsg.roleId
	user.role = role
	local ret = {}
	ret.err = 0
	ret.role = role
	return ret, "login", "CreateRoleR"
end


----
local function regist(id2, func)
	local id1 = 1
	if (type(id2) == "string") then
		id1, id2 = protMgr:getId("login", id2)
	end
	protMgr:registFunc(id1, id2, func)
end
for k, v in pairs(tbl) do
	if type(v) == "function" then
		regist(k, v)
	end
end