require "common"

ServerMgr = oo.class(nil, "ServerMgr")

function ServerMgr:__init()
	self.serverList = {}
end

function ServerMgr:regist( server, address )
	assert(self.serverList[server] == nil, "duplicate regist:"..server)
	self.serverList[server] = address
end

function ServerMgr:getAddress( server )
	return self.serverList[server]
end

function ServerMgr:check( server )
	

	return true;
end



--创建全局对象
if g_serverMgr == nil then
	g_serverMgr = ServerMgr()
end