
--module("gate_cmd", package.seeall)
local skynet = require "skynet"
local loginConn = loginConn
local playerMgr = g_playerMgr

local tbl = {}
-- login server disallow multi login, so login_handler never be reentry
-- call by login server
-- function tbl.login( uid, secret )
-- 	local context = playerMgr:contextByUid(uid)
-- 	if context then
-- 		error(string.format("%s is already login", uid))
-- 	end

-- 	local subId = playerMgr:incSubId()
-- 	local agent = skynet.newservice("playerd", loginConn)
-- 	assert(agent)
-- 	-- trash subid (no used)
-- 	local roleId = skynet.call(agent, "lua", "login", uid, subId, "platform", "area", secret)
-- 	playerMgr:waitLogin(agent, uid, subid, "platform", "area", roleId, secret)

-- 	-- you should return unique subid
-- 	return subId
-- end

-- call by agent(player)
function tbl.logout( roleId )
	--playerMgr:logout(roleId)
	--skynet.call(loginservice, "lua", "logout", roleId)
end

-- call by login server
function tbl.kick( roleId, subid )
	playerMgr:kickOut(roleId)
end

-- call by agent(player) server
function tbl.sendClient( roleId, package, size )
	playerMgr:sendClient(roleId, package, size)
end

-- call by login server
function tbl.loadRole( roleId )
	local context = playerMgr:contextByRoleId(roleId)
	if context then
		--error(string.format("%s is already login", uid))
		playerMgr:waitLogin(agent, roleId, "token")
	else
		local agent = skynet.newservice("playerd", loginConn)
		assert(agent)

		local ok = skynet.call(agent, "lua", "load", roleId)
		if ok then
			playerMgr:waitLogin(agent, roleId, "token")
		end
	end
	return ok
end

-- call by login server, 在登陆服登陆的时候
function tbl.createRole( role )
	local roleId = playerMgr:genRoleId()
	local agent = skynet.newservice("playerd", loginConn)
	assert(agent)
	role.roleId = roleId
	local err = skynet.call(agent, "lua", "init", role)
	if err == 0 then
		playerMgr:newRole(agent, roleId)
	end
	return {err=err, roleId=roleId}
end

return tbl