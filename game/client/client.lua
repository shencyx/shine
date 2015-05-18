package.cpath = "luaclib/?.so"
package.path = package.path..";lualib/?.lua"
package.path = package.path..";pj/client/?.lua"

local socket = require "clientsocket"
local crypt = require "crypt"
local pb = require "protobuf"

if _VERSION ~= "Lua 5.3" then
	error "Use lua 5.3"
end

local prot = require "client_prot"
local send_pb = prot.send_pb
local read_pb = prot.read_pb
local last = prot.last



local fd = assert(socket.connect("127.0.0.1", 7700))

--注册
local uid = ...
uid = uid or "shencyx"
local verify = {
	account = uid,
	platform = "demo",
	area = "1区",
	password = "password"
}
send_pb(fd, "login.Regist", verify, 1, 1)

local pb_package, pb_msg, pb_buf = read_pb(fd)
local registR = pb.decode("login.RegistR" , pb_buf)
print(registR.err)

--如果已注册就登录
if registR.err == 101 then
	send_pb(fd, "login.Login", verify, 1, 3)
	local loginR = read_pb(fd, "login.LoginR")
end

--取角色
send_pb(fd, "login.GetRole", {}, 1, 6)
local getRoleR = read_pb(fd, "login.GetRoleR")

if not next(getRoleR.roleList) then
	--创建角色
	local role = {
		roleId = 0,
		name = "name",
		occ = 1,
		gender = 1,
		camp = 1,
		level = 1,
	}
	send_pb(fd, "login.CreateRole", {role=role}, 1, 8)
	local createRoleR = read_pb(fd, "login.CreateRoleR")
	roleId = createRoleR.role.roleId
	print("create role: err, roleId",createRoleR.err, roleId)
else
	roleId = getRoleR.roleList[1].roleId
end

local entry = {
	roleId = roleId,
}
send_pb(fd, "login.Entry", entry, 1, 10)
local entryR = read_pb(fd, "login.EntryR")
print("entryR:", entryR.err, entryR.ip, entryR.port)

socket.close(fd)
print("login ok! ")

----- connect to game server --------------------------

local text = "echo"
local index = 1

print("connect game")
local fd = assert(socket.connect(entryR.ip, entryR.port))
last = ""


local loginMsg = {
	roleId = roleId,
	token = "just for test!",
}
send_pb(fd, "base.Login", loginMsg, 2, 1)


local pb_package, pb_msg, pb_buf = read_pb(fd)
print("readpackage!", pb_package, pb_msg)
local login_back = pb.decode("base.LoginR" , pb_buf)
local role = login_back.role
print(login_back.err, role.roleId, role.name, role.level)

--取背包信息
local getBag = {}
send_pb(fd, "bag.GetBag", getBag, 3, 1)
-- local Item = {id = 101, name ="物品", type = 223}
-- send_pb(fd, "bag.Item", Item, 2, 2)
while true do
	local pb_package, pb_msg, pb_buf = read_pb(fd)
	print("read package size:", size, pb_package, pb_msg)
end
print("disconnect")
socket.close(fd)
--[[
index = index + 1

print("connect again")
local fd = assert(socket.connect("127.0.0.1", 8888))
last = ""

local handshake = string.format("%s@%s#%s:%d", crypt.base64encode(token.user), crypt.base64encode(token.server),crypt.base64encode(subid) , index)
local hmac = crypt.hmac64(crypt.hashkey(handshake), secret)

send_package(fd, handshake .. ":" .. crypt.base64encode(hmac))

print(readpackage())
print("===>",send_request("fake",0))	-- request again (use last session 0, so the request message is fake)
print("===>",send_request("again",1))	-- request again (use new session)
print("<===",recv_response(readpackage()))
print("<===",recv_response(readpackage()))


print("disconnect")
socket.close(fd)
]]
