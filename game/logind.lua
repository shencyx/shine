require "common"
local crypt = require "crypt"
local skynet = require "skynet"
local snax = require "snax"

local project_name = skynet.getenv "project_name"
util.add_path("./"..project_name.."/login/?.lua")

local login = require "my_login_server"

-- local mysqld = ...
-- if mysqld then
-- 	_ismaster = true
-- 	mysqld = snax.bind(tonumber(mysqld), "mysqld")
-- end


--逻辑代码
require "server_mgr"
require "user_mgr"




--配置ip，端口
local server = {
	host = "0.0.0.0",
	port = 8001,
	multilogin = false,	-- disallow multilogin
	name = "login_master",
}

server.instance = 4		--开多少个从登陆服

-- 验证token, 
function server.auth_handler(token)
	-- the token is base64(user)@base64(server):base64(password)
	local user, serverName, password = token:match("([^@]+)@([^:]+):(.+)")
	user = crypt.base64decode(user)
	serverName = crypt.base64decode(serverName)
	password = crypt.base64decode(password)
	assert(password == "password")
	return serverName, user
end

--临时用自己的
function server.auth_handler(account, serverId, verifyKey)
	local user = account
	local serverName = ""
	if serverId == 1 then
		serverName = "sample"
	end
	return serverName, user
end

function server.login_handler(serverName, uid, secret)
	print(string.format("%s@%s is login, secret is %s", uid, serverName, crypt.hexencode(secret)))
	--local gameserver = assert(server_list[server], "Unknown server")
	local serverAddress = g_serverMgr:getAddress(serverName)
	if serverAddress == nil then
		skynet.error("login_handler")
	end
	-- only one can login, because disallow multilogin
	local last = g_userMgr:getUser(uid)
	if last then
		skynet.call(last.address, "lua", "kick", uid, last.subid)
	end
	if g_userMgr:getUser(uid) then
		error(string.format("user %s is already online", uid))
	end

	local subid = tostring(skynet.call(serverAddress, "lua", "login", uid, secret))
	g_userMgr:login(uid, subid, serverName, serverAddress)

	return subid
end


local CMD = require "login_cmd"
function server.command_handler(command, source, ...)
	local f = assert(CMD[command])
	return f(source, ...)
end

login(server)
