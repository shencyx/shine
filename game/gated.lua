--
-- gated 服务只做客户端连接的socket管理（验证，断开等）不需要发送数据
--
require "common"
local skynet = require "skynet"
local snax = require "snax"
local gateserver = require "snax.gateserver"
local netpack = require "netpack"
local crypt = require "crypt"
local socketdriver = require "socketdriver"
local assert = assert
local b64encode = crypt.base64encode
local b64decode = crypt.base64decode

--util.add_path("./blue/gate/?.lua")
local project_name = skynet.getenv "project_name"
util.add_path("./"..project_name.."/gate/?.lua")
--util.add_path("./"..project_name.."/protocol/?.lua")


local pb = require "protobuf"
pb.register_file "pj/protocol/base.pb"


local function send_pb(fd, pb_type, pb_table)
	local stringbuffer = pb.encode(pb_type, pb_table)
	local size = 2 + #stringbuffer
	local buf = string.pack(">I2", size)..string.pack(">I1", 1)..string.pack(">I1", 2)..stringbuffer
	--socket.write(fd, buf)
	socketdriver.send(fd, buf, size)
end

--[[

Protocol:

	All the number type is big-endian

	Shakehands (The first package)

	Client -> Server :

	base64(uid)@base64(server)#base64(subid):index:base64(hmac)

	Server -> Client

	XXX ErrorCode
		404 User Not Found
		403 Index Expired
		401 Unauthorized
		400 Bad Request
		200 OK

	Req-Resp

	Client -> Server : Request
		word size (Not include self)
		string content (size-4)
		dword session

	Server -> Client : Response
		word size (Not include self)
		string content (size-5)
		byte ok (1 is ok, 0 is error)
		dword session

API:
	server.userid(username)
		return uid, subid, server

	server.username(uid, subid, server)
		return username

	server.login(username, secret)
		update user secret

	server.logout(username)
		user logout

	server.ip(username)
		return ip when connection establish, or nil

	server.start(conf)
		start server

Supported skynet command:
	kick username (may used by loginserver)
	login username secret  (used by loginserver)
	logout username (used by agent)

Config for server.start:
	conf.expired_number : the number of the response message cached after sending out (default is 128)
	conf.login_handler(uid, secret) -> subid : the function when a new user login, alloc a subid for it. (may call by login server)
	conf.logout_handler(uid, subid) : the functon when a user logout. (may call by agent)
	conf.kick_handler(uid, subid) : the functon when a user logout. (may call by login server)
	conf.request_handler(username, session, msg, sz) : the function when recv a new request.
	conf.register_handler(servername) : call when gate open
	conf.disconnect_handler(username) : call when a connection disconnect (afk)
]]

--登陆服地址id
loginConn, mysqld = ...
loginConn = tonumber(loginConn)
-- loginservice = tonumber(loginservice)
-- mysqld = snax.bind(tonumber(mysqld), "mysqld")

--逻辑代码
require "player_mgr"


local expired_number = 128
local internal_id = 0


skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
}

local handshake = {}	--连接上来但还未进行登陆验证的玩家


-- call by self (when socket disconnect)
local function disconnect_handler(uid)
	g_playerMgr:onDisconnect(uid)
end

-- call by self (when recv a request from client)
local function request_handler(roleId, msg, sz)
	local u = g_playerMgr:contextByRoleId(roleId)
	--return skynet.tostring(skynet.rawcall(u.agent, "client", msg, sz))
	return skynet.rawcall(u.agent, "client", msg, sz)
end

-- call by self (when gate open)
local function register_handler(name)
	servername = name
	--skynet.call(loginservice, "lua", "register_gate", servername, skynet.self())
	--local ret = skynet.call(loginConn, "lua", "call", "test", {msg = "what a good day!"})
	--print_r(ret)
end


------------------------------------------------------------------------------
local handler = {}

local CMD = require "gate_cmd"
function handler.command(cmd, source, ...)
	local f = assert(CMD[cmd])
	return f(...)
end

function handler.open(source, gateconf)
	local servername = assert(gateconf.servername)
	return register_handler(servername)
end

function handler.connect(fd, addr)
	handshake[fd] = addr
	gateserver.openclient(fd)
end

function handler.disconnect(fd)
	handshake[fd] = nil
	local c = g_playerMgr:contextByFd(fd)
	if c then
		c.fd = nil
		g_playerMgr:fdToContext(fd, nil)
		disconnect_handler(c.uid)
	end
end

handler.error = handler.disconnect

-- atomic , no yield
local function do_auth(fd, message, addr)
	local username, index, hmac = string.match(message, "([^:]*):([^:]*):([^:]*)")
	local uid, servername, subid = g_playerMgr:parserName(username)
	local u = g_playerMgr:contextByUid(uid)
	if u == nil then
		return "404 User Not Found"
	end
	local idx = assert(tonumber(index))
	hmac = b64decode(hmac)

	if idx <= u.version then
		return "403 Index Expired"
	end

	local text = string.format("%s:%s", username, index)
	local v = crypt.hmac64(crypt.hashkey(text), u.secret)
	if v ~= hmac then
		return "401 Unauthorized"
	end

	u.version = idx
	u.fd = fd
	u.ip = addr
	g_playerMgr:fdToContext(fd, u)
end

local function auth(fd, addr, msg, sz)
	local message = netpack.tostring(msg, sz)
	local ok, result = pcall(do_auth, fd, message, addr)
	if not ok then
		skynet.error(result)
		result = "400 Bad Request"
	end

	local close = result ~= nil

	if result == nil then
		result = "200 OK"
	end

	socketdriver.send(fd, netpack.pack(result))

	if close then
		gateserver.closeclient(fd)
	end
end

local function my_auth(fd, addr, msg, sz)
	local close = false
	local message = netpack.tostring(msg, sz)
	local pb_package, pb_msg, pb_buf = string.unpack(">I1>I1c"..(sz-2), message)
	local loginMsg = pb.decode("base.Login" , pb_buf)

	--验证token是否合法
	if loginMsg.token then
		skynet.error("role login! id:", loginMsg.roleId)
		local u = g_playerMgr:contextByRoleId(loginMsg.roleId)
		if u == nil then
			close = true
		else
			u.version = 1
			u.fd = fd
			u.ip = addr
			g_playerMgr:fdToContext(fd, u)
			skynet.send(u.agent, "lua", "afterAuth")
		end
	else
		close = true
	end

	--这里只是测试用
	-- local loginR = {
	-- 	roleId = 1001,
	-- 	name = "测试号",
	-- 	occ = 3,
	-- 	gender = 1,
	-- 	camp = 2,
	-- 	level = 4,
	-- }
	-- send_pb(fd, "base.Role", loginR)

	if close then
		gateserver.closeclient(fd)
	end
end


-- u.response is a struct { return_fd , response, version, index }
local function retire_response(u)
	if u.index >= expired_number * 2 then
		local max = 0
		local response = u.response
		for k,p in pairs(response) do
			if p[1] == nil then
				-- request complete, check expired
				if p[4] < expired_number then
					response[k] = nil
				else
					p[4] = p[4] - expired_number
					if p[4] > max then
						max = p[4]
					end
				end
			end
		end
		u.index = max + 1
	end
end

local function do_request(fd, msg, sz)
	local u = assert(g_playerMgr:contextByFd(fd), "invalid fd")
	local msg_sz = sz - 4
	local session = netpack.tostring(msg, sz, msg_sz)
	local p = u.response[session]
	if p then
		-- session can be reuse in the same connection
		if p[3] == u.version then
			local last = u.response[session]
			u.response[session] = nil
			p = nil
			if last[2] == nil then
				local error_msg = string.format("Conflict session %s", crypt.hexencode(session))
				skynet.error(error_msg)
				error(error_msg)
			end
		end
	end

	if p == nil then
		p = { fd }
		u.response[session] = p
		local ok, result = pcall(request_handler, u.uid, msg, msg_sz)
		result = result or ""
		-- NOTICE: YIELD here, socket may close.
		if not ok then
			skynet.error(result)
			result = "\0" .. session
		else
			result = result .. '\1' .. session
		end

		p[2] = netpack.pack_string(result)
		p[3] = u.version
		p[4] = u.index
	else
		netpack.tostring(msg, sz) -- request before, so free msg
		-- update version/index, change return fd.
		-- resend response.
		p[1] = fd
		p[3] = u.version
		p[4] = u.index
		if p[2] == nil then
			-- already request, but response is not ready
			return
		end
	end
	u.index = u.index + 1
	-- the return fd is p[1] (fd may change by multi request) check connect
	fd = p[1]
	--if connection[fd] then
	if g_playerMgr:contextByFd(fd) then
		socketdriver.send(fd, p[2])
	end
	p[1] = nil
	retire_response(u)
end

--把客户端的消息包转发到playerd
local function do_request(fd, msg, sz)
	local u = assert(g_playerMgr:contextByFd(fd), "invalid fd")
	local ok, result, size = pcall(request_handler, u.roleId, msg, sz)
	result = result or ""
	-- NOTICE: YIELD here, socket may close.
	if not ok then
		skynet.error(result)
	else
		--print("result, size: ",result, size)
	end

	if g_playerMgr:contextByFd(fd) then
		--socketdriver.send(fd, netpack.pack(result, size))
		socketdriver.send(fd, result, size)
	end

	retire_response(u)
end

--把客户端的消息包转发到playerd
local function request(fd, msg, sz)
	local ok, err = pcall(do_request, fd, msg, sz)
	-- not atomic, may yield
	if not ok then
		skynet.error(string.format("Invalid package %s : %s", err, netpack.tostring(msg, sz)))
		if g_playerMgr:contextByFd(fd) then
			gateserver.closeclient(fd)
		end
	end
end

function handler.message(fd, msg, sz)
	print("gate recv message:", fd, sz)
	local addr = handshake[fd]
	if addr then
		my_auth(fd,addr,msg,sz)
		handshake[fd] = nil
	else
		request(fd, msg, sz)
	end
end

--gate 监听连接端口
gateserver.start(handler)
