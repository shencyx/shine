require "common"
util.add_path("./login/?.lua")
util.add_path("./login/protocol/?.lua")

local skynet = require "skynet"
local snax = require "snax"


--全局变量
g_gate, g_userid, g_subid = nil, nil, nil
--mysqld = ...
--mysqld = snax.bind(tonumber(mysqld), "mysqld")


function __send_client(roleId, buf, sz )
	if g_gate then
		skynet.send(g_gate, "lua", "sendClient", roleId, buf, sz)
	end
end

-- local protMgr = require "protocol_include"
-- --逻辑
require "server_mgr"



local CMD = require "server_cmd"
local SOCKET = CMD.socket
skynet.start(function()
	-- 
	skynet.dispatch("lua", function(session, source, command, what, ...)
		local f 
		if command == 'socket' then
			f = assert(SOCKET[what], string.format("socket:%s", what))
			f(...)
		else
			f = assert(CMD[command], string.format("source:%s, command:%s", skynet.address(source), command))
			skynet.retpack(f(source, what, ...))
		end
	end)

end)

