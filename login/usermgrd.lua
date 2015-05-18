require "common"
util.add_path("./login/?.lua")
util.add_path("./login/protocol/?.lua")

local skynet = require "skynet"
local snax = require "snax"


--全局变量
serverMgr = ...
serverMgr = tonumber(serverMgr)
--mysqld = ...
--mysqld = snax.bind(tonumber(mysqld), "mysqld")

require("protocol_include", "usermgrd")
-- --逻辑
require "user_mgr"
require "login_oper"


local CMD = require "user_cmd"
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

