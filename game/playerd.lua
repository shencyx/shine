require "common"
util.add_path("./pj/?.lua")
util.add_path("./pj/player/?.lua")
util.add_path("./pj/protocol/?.lua")

local skynet = require "skynet"
local snax = require "snax"


--全局变量
loginConn = ...
loginConn = tonumber(loginConn)
g_gate, g_userid, g_subid = nil, nil, nil
--mysqld = ...
--mysqld = snax.bind(tonumber(mysqld), "mysqld")


function __send_client(roleId, buf, sz )
	if g_gate then
		skynet.send(g_gate, "lua", "sendClient", roleId, buf, sz)
	end
end

local protMgr = require "protocol_include"
--逻辑
require "player_include"

--处理gate转发过来的客户端消息
skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = skynet.tostring,
	dispatch = function (_, _, msg)
		local sz = #msg
		local ret, id1, id2 = protMgr:dispatch( msg, sz )
		if ret ~= nil then
			local retBuf, retSz = protMgr:pack(ret, id1, id2)
			skynet.ret(retBuf, retSz)
		end
	end
}


local CMD = require "player_cmd"
skynet.start(function()
	-- If you want to fork a work thread , you MUST do it in CMD.login
	skynet.dispatch("lua", function(session, source, command, ...)
		local f = assert(CMD[command], string.format("source:%s, command:%s", skynet.address(source), command))
		if command == "afterAuth" then	--这个调用不用返回
			f(source, ...)
		else
			skynet.retpack(f(source, ...))
		end
	end)

end)

