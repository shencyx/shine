
local skynet = require "skynet"
local sock = require "socket"
local userMgr = g_userMgr
local protMgr = protMgr

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

-------------------------------------------------------------------
function __send_client(fd, msg, id1, id2)
	local retBuf, retSz = protMgr:pack(msg, id1, id2)
	sock.write(fd, retBuf, retSz)
end

local socket = {}
function socket.open(fd, addr)
	print("socket connect!", fd, addr)
	skynet.call(gate, "lua", "accept", fd)
	--
	userMgr:onConnect(fd, addr)
end

function socket.close(fd)
	print("socket close",fd)
	userMgr:onClose(fd)
end

function socket.error(fd, msg)
	print("socket error",fd, msg)
	socket.close(fd)
end

local send_package = sock.write
local function doDispatch(fd, msg, sz)
	local user = userMgr:getUserByFd(fd)
	if type(user) == "string" then
		local msg, id1, id2 = protMgr:unpack(msg, sz)
		if id1 ~= 1 then
			socket.close(fd)
		elseif id2 == 1 then
			userMgr:Regist(fd, msg)
		elseif id2 == 3 then
			userMgr:Login(fd, msg)
		else
			socket.close(fd)
		end
	else
		local ret, id1, id2 = protMgr:dispatch(user, msg, sz)
		if ret ~= nil then
			local retBuf, retSz = protMgr:pack(ret, id1, id2)
			send_package(fd, retBuf, retSz)
		end
	end
end

function socket.data(fd, msg)
	print("socket data",fd, msg)
	local ok = doDispatch(fd, msg, #msg) or true
	--local ok, err = pcall(doDispatch, fd, msg, #msg)
	-- not atomic, may yield
	if not ok then
		skynet.error(string.format("Invalid client package fd:%d : err:%s", fd, err))
		socket.close(fd)
	end
end


tbl.socket = socket
return tbl