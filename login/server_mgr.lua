require "common"
local skynet = require "skynet"
local sock = require "socket"

local _sessionId = 0
local _thread = {}		--key:session value:co
local _msg = {}			--key:session valu:msg

local function genSessionId()
	_sessionId = 1 + _sessionId
	return _sessionId
end

ServerMgr = oo.class(nil, "ServerMgr")

function ServerMgr:__init()
	self.serverList = {}	--key:serverId value:server
	self.area2server = {}	--key:platform value:{ key:area value:serverId}
	self.fd2addr = {}
end

function ServerMgr:regist(fd, msg)
	print("ServerMgr:regist!", fd)
	assert(type(self.fd2addr[fd]) == "string")
	local platform = msg.platform
	local serverId = msg.serverId
	local server = self.serverList[serverId]
	if server == nil then
		server = {}
	end
	server.addr = self.fd2addr[fd]
	server.id = serverId
	server.fd = fd
	server.ip = msg.ip
	server.port = msg.port
	server.onlien = 0
	server.platform = msg.platform
	server.areaList = msg.areaList
	self.fd2addr[fd] = server

	if self.area2server[platform] == nil then
		self.area2server[platform] = {}
		platform = self.area2server[platform]
	else
		platform = self.area2server[platform]
	end
	for _, v in pairs(msg.areaList) do
		platform[v] = server
	end
	--
	print_r(server)
end

function ServerMgr:getAddress( server )
	return self.serverList[server]
end

function ServerMgr:check( server )
	

	return true;
end

function ServerMgr:send(fd, cmd, msg)
	local package = string.pack(">s2", skynet.packstring(cmd, msg))
	sock.write(fd, package)
end

function ServerMgr:push(fd, cmd, msg)
	local id = genSessionId()
	msg.session = id
	msg.cmd = cmd
	self:send(fd, "push", msg)
	local co = coroutine.running()
	_thread[id] = co
	skynet.wait()
	local rmsg = _msg[id]
	_msg[id] = nil
	return rmsg
end

function ServerMgr:onConnect(fd, addr)
	self.fd2addr[fd] = addr
	local msg = self:push(fd, "onConnect", {})
	self:regist(fd, msg)
end

function ServerMgr:onClose(fd)
	self.fd2addr[fd] = nil
end

function ServerMgr:ping(fd, msg )
	--print("ping-->", fd)
end

function ServerMgr:test( fd, msg )
	print_r(msg)

	return msg
end

function ServerMgr:response(session, msg)
	local co = _thread[session]
	_thread[session] = nil
	_msg[session] = msg
	skynet.wakeup(co)
end

-----------------------------------------------
--内部命令
function ServerMgr:getServer(platform, area)
	local p = self.area2server[platform]
	return p and p[area]
end

function ServerMgr:loadRole(roleId, platform, area)
	print("loadRole:", roleId, platform, area)
	local s = self:getServer(platform, area)
	local ret = self:push(s.fd, "loadRole", {roleId = roleId})
	return ret, s.ip, s.port, "token"
end

function ServerMgr:createRole(role, platform, area)
	local s = self:getServer(platform, area)
	local err, rid = self:push(s.fd, "createRole", role)
	print("ServerMgr:createRole:", err, rid)
	return err, rid
end


--创建全局对象
if g_serverMgr == nil then
	g_serverMgr = ServerMgr()
end