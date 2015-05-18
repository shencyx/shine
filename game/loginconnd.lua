require "common"
local skynet = require "skynet"
local sc = require "socketchannel"
local call = skynet.call

local gate

local function pack(cmd, msg)
	return string.pack(">s2", skynet.packstring(cmd, msg))
end

local function response( sock )
	local sz = sock:read(2)
	sz = string.unpack(">I2", sz)
	local cmd, msg = skynet.unpack(sock:read(sz))
	return cmd, true, msg
end

local channel
local cmd = {}
local push = {}

skynet.start(function()
	--
	skynet.dispatch("lua", function(session, source, command, ...)
		local f = assert(cmd[command], string.format("source:%s, command:%s", skynet.address(source), command))
		skynet.retpack(f(source, ...))
	end)
	--
	
end)

----------------------------------------------------
--内部(同节点)命令
function cmd.open(source, ip, port)
	gate = skynet.localname(".gated")
	channel = sc.channel {
	  host = ip,
	  port = tonumber(port),
	  response = response,
	}
	channel:connect()
	--
	skynet.fork(function()
		while true do
			--local msg = channel:response("push")
			local ok, msg = pcall(channel.response, channel, "push")
			if not ok then
				skynet.error("channel.response push error:", msg)
			else
				local cmd = msg.cmd
				local f = push[cmd]
				--local ok, err = pcall(f, msg)
				skynet.fork(function(msg)
					local r = f(msg)
					channel:request(pack(msg.session, r or {}))
				end, msg)
				if not ok then
					skynet.error("login push cmd error:", cmd)
				end
			end
		end
	end)
	--
	skynet.fork(function()
		while true do
			local ok, err = pcall(channel.request, channel, pack("ping", {}))
			if not ok then
				skynet.error("pint login error:", err)
			end
			skynet.sleep(1000)
		end
	end)
end

function cmd.call(source, cmd, msg)
	print("loginConn call", cmd)
	local ret = channel:request(pack(cmd, msg), cmd)
	return ret
end

function cmd.test(source, t)

end


-----------------------------------------------------
--登陆服发过来的命令
function push.onConnect(msg)
	print("onConnect")
	local message = {
		ip = "127.0.0.1",
		port = 8888,
		platform = "demo",
		serverId = 1,
		areaList = {"1区", "2区"}
	}
	return message
end

function push.loadRole( msg )
	print("loginconn loadRole", msg.roleId)
	local rmsg = call(gate, "lua", "loadRole", msg.roleId)
	return rmsg
end

function push.createRole(role)
	return call(gate, "lua", "createRole", role)
end