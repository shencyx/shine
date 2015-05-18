local skynet = require "skynet"
local snax = require "snax"


skynet.start(function()
	--
	--local mysqld = snax.uniqueservice("mysqld", "test")
	--
	--
	local serverMgr = skynet.newservice("servermgrd")
	--
	local userMgr = skynet.newservice("usermgrd", serverMgr)

	--最后再打开端口
	skynet.call(serverMgr, "lua", "listen", "0.0.0.0", 7701)
	skynet.call(userMgr, "lua", "listen", "0.0.0.0", 7700)
	skynet.exit()
end)
