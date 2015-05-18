

local login = require "snax.loginserver"
local crypt = require "crypt"
local skynet = require "skynet"

--其它服务调用的命令
local tbl = {}

function tbl.register_gate(server, address)
	print("register_gate:"..server..":"..address)
	g_serverMgr:regist(server, address)
	--g_userMgr:loadAccount()

end

function tbl.logout(uid, subid)
	g_userMgr:logout(uid, subid)
end


return tbl