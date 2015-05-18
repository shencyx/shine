require "common"
require "chunk"
local skynet = skynet

local CHUNK_WIDTH = 300
local CHUNK_HEIGHT = 300


SceneObj = oo.class(nil, "SceneObj")

function SceneObj:__init(id, data)
	self._id = id
	self._maxSize = 50
	self._data = 0
	self._width = 910
	self._height = 910
	self._ws = self._width // CHUNK_WIDTH + 1
	self._hs = self._height // CHUNK_HEIGHT + 1
	self._chunkList = {}	--第几行，几列
	for i = 1, self._hs do
		self._chunkList[i] = {}
		for j = 1, self._ws do
			self._chunkList[i][j] = Chunk()
		end
	end
	--
	for i = 1, self._hs do
		for j = 1, self._ws do
			local cobj = self._chunkList[i][j]
			local w = j - 1 > 0 and j - 1 or 1
			local h = i - 1 > 0 and i - 1 or 1
			local ws = j + 1 <= self._ws and j + 1 or self._ws
			local hs = i + 1 <= self._hs and i + 1 or self._hs
			for h = h, hs do
				for w = w, ws do
					self._chunkList[h][w]:addRound(cobj)
				end
			end
		end
	end
end

function SceneObj:checkPos( posX, posY )
	assert(posX > 0 and posX <= self._ws)
	assert(posY > 0 and posY <= self._hs)
end

function SceneObj:getChunk(posX, posY )
	self:checkPos(posX, posY)
	return self._chunkList[posY][posX]
end

function SceneObj:getChunkByObj(obj)
	local posX = obj._x // CHUNK_WIDTH + 1
	local posY = obj._y // CHUNK_HEIGHT + 1
	return self:getChunk(posX, posY)
end

--进入场景
function SceneObj:enter( obj, copyId )
	local msg = {
		sceneId = self._id,
		x = obj._x,
		y = obj._y,
	}
	_sendClient(obj._id, msg, "base", "EnterSceneR")
	--
	local cobj = self:getChunkByObj(obj)
	cobj:enter(obj)
end

--退出场景
function SceneObj:leave( obj )
	local cobj = self:getChunkByObj(obj)
	cobj:leave(obj)
end

--更新场景坐标
function SceneObj:update( obj, x, y )
	x = x < 1 and 1 or (x > self._width and self._width or x)
	y = y < 1 and 1 or (y > self._height and self._height or y)
	local cobjOld = self:getChunkByObj(obj)
	local posX = x // CHUNK_WIDTH + 1
	local posY = y // CHUNK_HEIGHT + 1
	local cobjNew = self:getChunk(posX, posY )
	obj._x = x
	obj._y = y
	if cobjOld == cobjNew then
		--cobjOld:update(obj, x, y)
		for o, _ in pairs(cobjOld._chunkList) do
			o:updatePos(obj)
		end
	else
		cobjOld:leave(obj)
		cobjNew:enter(obj)
		--离屏
		for o, _ in pairs(cobjOld._chunkList) do
			if cobjNew._chunkList[o] == nil then
				o:leaveScreen(obj)
			end
		end
		--入屏
		for o, _ in pairs(cobjNew._chunkList) do
			if cobjOld._chunkList[o] == nil then
				o:enterScreen(obj)
			else
				o:updatePos(obj)
			end
		end
	end
end

function SceneObj:broadcast9(obj, msg, id1, id2)
	local cobj = self:getChunkByObj(obj)
	for o, _ in pairs(cobj._chunkList) do
		o:broadcast(msg, id1, id2)
	end
end