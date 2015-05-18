require "common"
local mysql = require "mysql"

UserMgr = oo.class(nil, "UserMgr")

function UserMgr:__init()
	self.userList = {}
	
end

function UserMgr:getUser(uid)
	return self.userList[uid]
end

function UserMgr:login(uid, subid, server, address)
	local u = { address = address, subid = subid , server = server}
	self.userList[uid] = u
	print(string.format("%s@%s is login", uid, server))
end

function UserMgr:logout(uid, subid)
	local u = self.userList[uid]
	if u then
		print(string.format("%s@%s is logout", uid, u.server))
		self.userList[uid] = nil
	end
end

function UserMgr:check( server )
	

	return true;
end

function UserMgr:loadAccount()
	
	--local result = mysqld.req.query("select playerid from player_base_info")
	local db = mysql.connect{	
		host="127.0.0.1",
		port=3306,
		database="ddz_test",
		user="root",
		password="123456",
		max_packet_size = 1024 * 1024
	}
	assert(db)
	local result = db:query("select playerid,name,jeton,credit,password from player_base_info")
	print("load account:", #result)
	print_r(result[1000])
	print_r(result[2000])
	print_r(result[3000])
	print_r(result[3000])
	print_r(result[40000])
end

function UserMgr:collectgarbage()
	collectgarbage("collect")
end

--创建全局对象
if g_userMgr == nil then
	g_userMgr = UserMgr()
end