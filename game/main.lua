local skynet = require "skynet"
local snax = require "snax"


skynet.start(function()
	--
	--local mysqld = snax.uniqueservice("mysqld", "test")
	--
	local scened = snax.newservice("scened", "10000")
	skynet.name(".sc_10000", scened.handle)
	--同一进程的登陆服
	--local loginserver = skynet.newservice("logind")
	--连登陆服的连接
	local loginConn = skynet.newservice("loginconnd")
	skynet.name(".loginConn", loginConn)
	--
	local gate = skynet.newservice("gated", loginConn)
	skynet.name(".gated", gate)

	--等所有服务都好了，再打开端口
	skynet.call(loginConn, "lua", "open", "127.0.0.1", 7701)
	skynet.call(gate, "lua", "open" , {
		port = 8888,
		maxclient = 64,
		servername = "sample",
	})
	
end)
