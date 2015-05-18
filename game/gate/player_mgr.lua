require "common"
local assert = assert
local skynet = require "skynet"
local crypt = require "crypt"
local b64encode = crypt.base64encode
local b64decode = crypt.base64decode
local socketdriver = require "socketdriver"

local loginConn = loginConn
-- context:
-- {
-- 	secret = secret,
-- 	version = 0,
--  roleId = 0,
-- 	index = 0,
--	uid = uid,
-- 	username = username,
--  platform = platform,
--  area = area,
-- 	response = {},	-- response cache
--  fd = fd,
--	agent = ageut,
-- }

local roleId = 1000000

PlayerMgr = oo.class(nil, "PlayerMgr")

function PlayerMgr:__init()
	self.playerList = {}		--key:roleId

	--self.uidList = {}			--key:uid    value:context
	self.fdList = {}			--key:fd     value:context
	self.roleIdList = {}		--key:roleId     value:context

end
--[[
function PlayerMgr:parserName( username )
	local uid, servername, subid = username:match "([^@]*)@([^#]*)#(.*)"
	return b64decode(uid), b64decode(subid), b64decode(servername)
end

function PlayerMgr:genName( uid, subid, serverName )
	return string.format("%s@%s#%s", b64encode(uid), b64encode(serverName), b64encode(tostring(subid)))
end

function PlayerMgr:incSubId()
	self.subId = self.subId + 1
	return self.subId
end
]]
--登陆服通知等待这个玩家登陆
function PlayerMgr:waitLogin(agent, roleId, secret)
	--assert(self.roleIdList[roleId] == nil)
	if self.roleIdList[roleId] == nil then
		self.roleIdList[roleId] = {
			secret = secret,
			version = 0,
			index = 0,
			roleId = roleId,
			response = {},	-- response cache
			agent = agent,
		}
	else
		self.roleIdList[roleId].secret = secret
	end
	--self.uidList[uid] = self.roleIdList[roleId]
end

function PlayerMgr:newRole(agent, roleId)
	self:waitLogin(agent, roleId)
end

function PlayerMgr:contextByRoleId( roleId )
	return self.roleIdList[roleId]
end

function PlayerMgr:contextByFd( fd )
	return self.fdList[fd]
end

function PlayerMgr:fdToContext( fd, contest )
	self.fdList[fd] = contest
end

-- function PlayerMgr:login(roleId, subid, server, address)
-- 	local u = { address = address, roleId = roleId , server = server}
-- 	self.playerList[roleId] = u
-- 	print(string.format("---->%s@%s is login", uid, server))
-- end

function PlayerMgr:logout(roleId)
	local u = self.roleIdList[roleId]
	self.roleIdList[roleId] = nil
	if u.fd then
		gateserver.closeclient(u.fd)
		connection[u.fd] = nil
	end
end

function PlayerMgr:kickOut( roleId )
	local u = self.roleIdList[roleId]
	if u then
		-- NOTICE: logout may call skynet.exit, so you should use pcall.
		pcall(skynet.call, u.agent, "lua", "logout")
	end
end

function PlayerMgr:check( server )
	

	return true;
end

function PlayerMgr:onDisconnect( roleId )
	local u = self.roleIdList[roleId]
	if u then
		skynet.call(u.agent, "lua", "afk")
	end
end

function PlayerMgr:ip(roleId)
	local u = self.roleIdList[roleId]
	if u and u.fd then
		return u.ip
	end
end

function PlayerMgr:sendClient( roleId, package, size )
	local context = self.roleIdList[roleId]
	if context and context.fd then
		socketdriver.send(context.fd, package, size)
	end
end

function PlayerMgr:genRoleId()
	roleId = roleId + 1
	return roleId
end



--创建全局对象
if g_playerMgr == nil then
	g_playerMgr = PlayerMgr()
end