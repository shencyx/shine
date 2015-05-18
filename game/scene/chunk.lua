require "common"
local skynet = skynet


Chunk = oo.class(nil, "Chunk")

function Chunk:__init()
	self._objList = {}
	self._chunkList = {}  --周围的chunk,包括自己
end

function Chunk:addRound(cobj)
	self._chunkList[cobj] = 1
end

function Chunk:enter( obj, copyId )
	if self._objList[obj._id] ~= nil then
		skynet.error(string.format("duplicate enter! objId:%d, objType:%d",obj._id, obj._type))
		return
	end
	self._objList[obj._id] = obj
end

function Chunk:leave( obj )
	if self._objList[obj._id] == nil then
		return
	end
	self._objList[obj._id] = nil
end

function Chunk:update(obj, x, y)
	obj._x = x
	obj._y = y
end

function Chunk:enterScreen(obj)
	local msg = {
		roleId = obj._id,
	}
	for k, v in pairs(self._objList) do
		if v ~= obj then
			_sendClient(k, msg, "base", "EnterScreen")
		end
	end
end

function Chunk:leaveScreen(obj)
	local msg = {
		roleId = obj._id,
	}
	for k, v in pairs(self._objList) do
		if v ~= obj then
			_sendClient(k, msg, "base", "LeaveScreen")
		end
	end
end

function Chunk:updatePos( obj )
	local msg = {
		roleId = obj._id,
		x = obj._x,
		y = obj._y,
	}
	for k, v in pairs(self._objList) do
		--if v ~= obj then
			_sendClient(k, msg, "base", "UpdatePos")
		--end
	end
end

--广播
function Chunk:broadcast(msg, id1, id2)
	for k, v in pairs(self._objList) do
		_sendClient(k, msg, id1, id2)
	end
end