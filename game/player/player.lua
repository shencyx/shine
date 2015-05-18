require "common"
require "base"
require "bag"

local skynet = require "skynet"
local snax = require "snax"
local loginConn = loginConn

Player = oo.class(nil, "Player")

function Player:__init()
	self._roleId = 0
	self._name = ""
	self._base = Base()
	self._bag = Bag()
end

local __send_client = __send_client
local protMgr = protMgr
function Player:sendClient(msg, id1, id2)
	assert(type(msg) == "table")
	local buf, sz = protMgr:pack(msg, id1, id2)
	__send_client(self._roleId, buf, sz )
end

function Player:init(role)
	self._roleId = role.roleId
	self._name = role.name
	self._gender = role.gender
	self._occ = role.occ
	self._camp = role.camp
	self._level = role.level
	return 0
end

--登陆服要求加载玩家数据
function Player:onLogin(roleId)
	self._roleId = roleId
	
	-- local result = mysqld.req.query("select * from player_base_info where playerid = 10001")
	-- assert(#result == 1)
	-- result = result[1]

	-- self.jetton = result.jetton
	-- self.credit = result.credit
	-- self.name = result.name
	return self._roleId
end

function Player:onLogout()
	

end

function Player:logout()
	if g_gate then
		skynet.call(g_gate, "lua", "logout", g_userid, g_subid)
	end
	skynet.exit()
end

--通过gated验证后调用
function Player:onConnect( )
	print("Player:onConnect!")
	local role = {
		roleId = self._roleId,
		name = self._name,
		occ = 3,
		gender = 1,
		camp = 2,
		level = 4,
	}
	local loginR = {}
	loginR.err = 0
	loginR.role = role
	self:sendClient(loginR, "base", "LoginR")
	--
	self:enterScene(10000)
end

--now: 当前时间戳
function Player:onTimer( now )
	print("on timer:",now)
	if self._base._sceneId then
		self:updateScene()
	end
end

local sceneCache = {}
function Player:getSceneObj( sid )
	sid = sid or self._base._sceneId
	local sobj = sceneCache[sid]
	if sobj ~= nil then
		return sobj
	end
	local name = ".sc_"..sid
	local add = skynet.localname(name)
	local sobj = snax.bind(tonumber(add), "scened")
	sceneCache[sid] = sobj
	return sobj
end

function Player:enterScene( sid )
	local sobj = self:getSceneObj(sid)
	local err, x, y = sobj.req.enter(self._roleId, nil)
	if err == 0 then
		local base = self._base
		base._sceneId = sid
		base._x = x
		base._y = y
	end
end

function Player:leaveScene( )
	local sobj = self:getSceneObj()
	local err = sobj.req.leave(self._roleId)
	self._base._sceneId = nil
	self._base._lastId = sid
end

function Player:updateScene( )
	local base = self._base
	base:autoMove()
	local sobj = self:getSceneObj(base._sceneId)
	sobj.post.update(self._roleId, base._x, base._y)
end


--创建全局对象
if g_player == nil then
	g_player = Player()
end