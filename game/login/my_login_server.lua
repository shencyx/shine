local skynet = require "skynet"
local socket = require "socket"
local crypt = require "crypt"
local table = table
local string = string
local assert = assert

local pb = require "protobuf"
pb.register_file "pj/protocol/account.pb"


--[[

Protocol:

	line (\n) based text protocol

	1. Server->Client : base64(8bytes random challenge)
	2. Client->Server : base64(8bytes handshake client key)
	3. Server: Gen a 8bytes handshake server key
	4. Server->Client : base64(DH-Exchange(server key))
	5. Server/Client secret := DH-Secret(client key/server key)
	6. Client->Server : base64(HMAC(challenge, secret))
	7. Client->Server : DES(secret, base64(token))
	8. Server : call auth_handler(token) -> server, uid (A user defined method)
	9. Server : call login_handler(server, uid, secret) ->subid (A user defined method)
	10. Server->Client : 200 base64(subid)

Error Code:
	400 Bad Request . challenge failed
	401 Unauthorized . unauthorized by auth_handler
	403 Forbidden . login_handler failed
	406 Not Acceptable . already in login (disallow multi login)

Success:
	200 base64(subid)
]]

--解包函数,2个字节长度
local last = ""
local function unpack_package(text)
	--print("=================================", #text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, text
	end
	print("revet package size", s)
	return text:sub(3,2+s), text:sub(3+s), s
end

local function unpack_f(f)
	local function try_recv(fd, last)
		local result, s
		result, last, s = f(last)
		if result then
			return result, last, s
		end
		local r = socket.read(fd)
		if not r then
			return nil, last
		end
		if r == "" then
			error "Server closed"
		end
		return f(last .. r)
	end

	return function(fd)
		while true do
			local result, size
			result, last, size = try_recv(fd, last)
			if result then
				return result, size
			end
			socket.usleep(100)
		end
	end
end

local readpackage = unpack_f(unpack_package)

local socket_error = {}
local function assert_socket(v, fd)
	if v then
		return v
	else
		skynet.error(string.format("auth failed: socket (fd = %d) closed", fd))
		error(socket_error)
	end
end

local function write(fd, text)
	assert_socket(socket.write(fd, text), fd)
end

local function send_pb(fd, pb_type, pb_table)
	local stringbuffer = pb.encode(pb_type, pb_table)
	local size = 2 + #stringbuffer
	local package = string.pack(">I2", size)..string.pack(">I1", 1)..string.pack(">I1", 2)..stringbuffer
	print("send_pb", size)
	write(fd, package)
end

local function launch_slave(auth_handler)
	local function auth(fd, addr)	--slave login的验证过程
		fd = assert(tonumber(fd))
		skynet.error(string.format("connect from %s (fd = %d)", addr, fd))
		socket.start(fd)

		-- set socket buffer limit (8K)
		-- If the attacker send large package, close the socket
		socket.limit(fd, 8192)
--[[
		--第一步 生成随机8字节challenge 给客户端
		--1. Server->Client : base64(8bytes random challenge)
		local challenge = crypt.randomkey()
		write(fd, crypt.base64encode(challenge).."\n")

		--第二步 收客户端8字节 handshake 经base64解码成 clientkey
		--2. Client->Server : base64(8bytes handshake client key)
		local handshake = assert_socket(socket.readline(fd), fd)
		local clientkey = crypt.base64decode(handshake)
		if #clientkey ~= 8 then
			error "Invalid client key"
		end

		--第三步 生成8字节 serverkey
		--3. Server: Gen a 8bytes handshake server key
		local serverkey = crypt.randomkey()
		--4. Server->Client : base64(DH-Exchange(server key))
		write(fd, crypt.base64encode(crypt.dhexchange(serverkey)).."\n")
		--5. Server/Client secret := DH-Secret(client key/server key)
		local secret = crypt.dhsecret(clientkey, serverkey)
		--6. Client->Server : base64(HMAC(challenge, secret))
		local response = assert_socket(socket.readline(fd), fd)
		--验证客户端发过来的 response 与服务器按相同规则生成的 hmac是否一致
		local hmac = crypt.hmac64(challenge, secret)
		if hmac ~= crypt.base64decode(response) then
			write(fd, "400 Bad Request\n")
			error "challenge failed"
		end
		--7. Client->Server : DES(secret, base64(token))
		local etoken = assert_socket(socket.readline(fd),fd)
		--对客户端发过来的token进行des解密
		local token = crypt.desdecode(secret, crypt.base64decode(etoken))
		
		--调用logind 的auth_handler 对token 验证
		--8. Server : call auth_handler(token) -> server, uid (A user defined method)
		local ok, server, uid =  pcall(auth_handler,token)
]]
		--上面的步骤暂时不用 
		local package_buf, size = readpackage(fd)
		local pb_package, pb_msg, pb_buf = string.unpack(">I1>I1c"..(size-2), package_buf)
		print("readpackage", size, pb_package, pb_msg)
		local verify = pb.decode("Account.Verify" , pb_buf)
		print(verify.account, verify.verifyKey, verify.serverId)

		--local token = assert_socket(socket.readline(fd),fd)
		local ok, server, uid =  pcall(auth_handler,verify.account, verify.serverId, verify.verifyKey)
		secret = verify.verifyKey --
		socket.abandon(fd)
		return ok, server, uid, secret
	end

	local function ret_pack(ok, err, ...)
		if ok then
			skynet.ret(skynet.pack(err, ...))
		else
			error(err)
		end
	end

	skynet.dispatch("lua", function(_,_,...)
		ret_pack(pcall(auth, ...))
	end)
end

local user_login = {}

--接受客户端接连，conf是logind定义的函数，s是某个slave login
local function accept(conf, s, fd, addr)
	-- call slave auth
	local ok, server, uid, secret = skynet.call(s, "lua",  fd, addr)
	socket.start(fd)

	if not ok then
		write(fd, "401 Unauthorized\n")
		error(server)
	end

	if not conf.multilogin then
		if user_login[uid] then
			write(fd, "406 Not Acceptable\n")
			error(string.format("User %s is already login", uid))
		end

		user_login[uid] = true
	end
	--9. Server : call login_handler(server, uid, secret) ->subid (A user defined method)
	local ok, err = pcall(conf.login_handler, server, uid, secret)
	-- unlock login
	user_login[uid] = nil

	if ok then
		err = err or ""
		--10. Server->Client : 200 base64(subid)
		--write(fd,  "200 "..crypt.base64encode(err).."\n")
		local verify_back = {
			roleId = "1001",
			ip = "192.168.3.6",
			port = 8888,
		}
		send_pb(fd, "Account.VerifyBack", verify_back)
	else
		write(fd,  "403 Forbidden\n")
		error(err)
	end
end

local function launch_master(conf)
	local instance = conf.instance or 8
	assert(instance > 0)
	local host = conf.host or "0.0.0.0"
	local port = assert(tonumber(conf.port))
	local slave = {}
	local balance = 1

	 --master login 处理command_handler的命令
	skynet.dispatch("lua", function(_,source,command, ...)
		skynet.ret(skynet.pack(conf.command_handler(command, ...)))
	end)

	for i=1,instance do
		table.insert(slave, skynet.newservice(SERVICE_NAME))
	end

	skynet.error(string.format("login server listen at : %s %d", host, port))
	local id = socket.listen(host, port)
	socket.start(id , function(fd, addr)
		local s = slave[balance]
		balance = balance + 1
		if balance > #slave then
			balance = 1
		end
		local ok, err = pcall(accept, conf, s, fd, addr)
		if not ok then
			if err ~= socket_error then
				skynet.error(string.format("invalid client (fd = %d) error = %s", fd, err))
			end
			socket.start(fd)
		end
		socket.close(fd)
	end)
end

local function login(conf)
	local name = "." .. (conf.name or "login")
	skynet.start(function()
		local loginmaster = skynet.localname(name)
		if loginmaster then
			local auth_handler = assert(conf.auth_handler)
			launch_master = nil
			conf = nil
			launch_slave(auth_handler)
		else
			launch_slave = nil
			conf.auth_handler = nil
			assert(conf.login_handler)
			assert(conf.command_handler)
			skynet.register(name)
			launch_master(conf)
		end
	end)
end

return login
