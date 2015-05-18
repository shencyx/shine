--内部协议
--module("player_cmd", package.seeall)
local skynet = require "skynet"

--全局变量
--g_gate, g_userid, g_subid
local player = g_player
local tbl = {}

--call by logind，登陆服要求加载玩家数据
function tbl.load(source, roleId)
	-- you may use secret to make a encrypted data stream
	skynet.error(string.format(">>>>>load role %d", roleId))
	-- g_gate = source
	-- g_userid = uid
	-- g_subid = sid
	_G['g_gate'] = source
	local ok = player:onLogin(roleId)
	--定时器
	skynet.fork(function()
		while true do
			player:onTimer(math.floor(skynet.time()))
			skynet.sleep(300)
		end
	end)
	return ok
end

function tbl.init(source, role)
	return player:init(role)
end

--call by self/logind
function tbl.logout(source)
	-- NOTICE: The logout MAY be reentry
	skynet.error(string.format(">>>>> %s is logout", g_userid))
	player:logout()
end

--call by gated, 客户端连接上并验证通过
function tbl.afterAuth(source)
	player:onConnect()
end

--call by gated
function tbl.afk(source)
	-- the connection is broken, but the user may back
	skynet.error(string.format("AFK"))
end

return tbl