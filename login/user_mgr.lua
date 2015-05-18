require "common"
local skynet = require "skynet"
local call = skynet.call
local sock = require "socket"


UserMgr = oo.class(nil, "UserMgr")

function UserMgr:__init()
	self.fd2addr = {}
	self.userList = {}		--key:uid(account), value:user
	self.roleIdList = {}	--key:roleId, value:user
end

function UserMgr:getUserByRoleId(roleId)
	return self.roleIdList[roleId]
end

function UserMgr:getUserByFd(fd)
	return self.fd2addr[fd]
end


function UserMgr:onConnect(fd, addr)
	self.fd2addr[fd] = addr
end

function UserMgr:onClose(fd)
	self.fd2addr[fd] = nil
end
--用户注册
function UserMgr:Regist(fd, msg)
	print("user regist fd:", fd)
	print_r(msg)
	local err = 0
	if self.userList[msg.account] then
		err = 101
	else
		local user = {
			uid = msg.account,
			platform = msg.platform,
			area = msg.area,
			role = nil,
			--roleId = 10011,
			addr = self.fd2addr[fd],
		}
		self.userList[msg.account] = user
		self.fd2addr[fd] = user
		--self.roleIdList[roleId] = user
	end
	self:sendClient(fd, {err = err}, "login", "RegistR")
end

--用户登陆
function UserMgr:Login(fd, msg)
	print("user Login fd:", fd)
	print_r(msg)
	local err = 0
	local user = self.userList[msg.account]
	if user == nil then
		err = 102
	end
	if err == 0 then
		self.fd2addr[fd] = user
	end
	self:sendClient(fd, {err = err}, "login", "LoginR")
end

function UserMgr:sendClient(fd, msg, id1, id2)
	__send_client(fd, msg, id1, id2)
end

if g_userMgr == nil then
	g_userMgr = UserMgr()
end