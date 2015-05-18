
local skynet = require "skynet"
local sock = require "socket"
local serverMgr = g_serverMgr

local gate = nil
local tbl = {}

function tbl.listen(source, ip, port)
	gate = skynet.newservice("gate")
	skynet.call(gate, "lua", "open" , {
		address = ip,
		port = port,
		--maxclient = max_client,
		--nodelay = true,
	})

end

function tbl.loadRole(source, roleId, platform, area)
	return  serverMgr:loadRole(roleId, platform, area)
end

function tbl.createRole(source, role, platform, area)
	return  serverMgr:createRole(role, platform, area)
end
-------------------------------------------------------------------
local function send_package(fd, cmd, msg)
	local package = string.pack(">s2", skynet.packstring(cmd, msg))
	sock.write(fd, package)
end

local socket = {}
function socket.open(fd, addr)
	print("socket connect!", fd, addr)
	skynet.call(gate, "lua", "accept", fd)
	--
	serverMgr:onConnect(fd, addr)
end

function socket.close(fd)
	print("socket close",fd)
	serverMgr:onClose(fd)
end

function socket.error(fd, msg)
	print("socket error",fd, msg)
	socket.close(fd)
end

function socket.data(fd, msg)
	print("server socket data",fd)
	local cmd, msg = skynet.unpack(msg)
	if type(cmd) == "number" then
		serverMgr:response(cmd, msg)
	else
		local ret = serverMgr[cmd](serverMgr, fd, msg)
		if ret ~= nil then
			send_package(fd, cmd, ret)
		end
	end
end


tbl.socket = socket
return tbl