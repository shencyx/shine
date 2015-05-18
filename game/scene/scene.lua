require "common"
require "scene_obj"
require "human_obj"
--local skynet = require "skynet"

SCENE_TYPE = {
	COMMON = 1,		--普通场景
	COPY = 2,		--副本
}

Scene = oo.class(nil, "Scene")

function Scene:__init(id)
	self._id = id
	self._maxSize = 50
	self._type = SCENE_TYPE.COMMON
	self._copyList = {}		--key:copyId value:SceneObj
	self._objList = {}		--在这个场景里的所有对象
	self._data = nil
	if self._type == SCENE_TYPE.COMMON then
		self._sceneObj = SceneObj(self._data )
	end
end


--进入场景
function Scene:enter( roleId, copyId )
	assert(self._objList[roleId] == nil)
	local obj = HumanObj(roleId)
	local sobj = nil
	if self._type == SCENE_TYPE.COMMON then
		sobj = self._sceneObj
	else
		sobj = self._copyList[copyId]
		if sobj == nil then
			sobj = SceneObj(self._data )
			self._copyList[copyId] = sobj
		end
	end
	--
	self._objList[obj._id] = obj
	obj._x = 50
	obj._y = 50
	sobj:enter(obj)
	return 0, obj._x, obj._y
end

function Scene:getSceneObj(copyId)
	local sobj = nil
	if self._type == SCENE_TYPE.COMMON then
		sobj = self._sceneObj
	else
		sobj = self._copyList[copyId]
	end
	return sobj
end

--退出场景
function Scene:leave( roleId )
	local obj = self._objList[roleId]
	local sobj = self:getSceneObj(obj._copyId)
	sobj:leave(obj)
	self._objList[obj._id] = nil
end

--更新坐标
function Scene:update(roleId, x, y)
	local obj = self._objList[roleId]
	local sobj = self:getSceneObj(obj._copyId)
	sobj:update(obj, x, y)
end

--九宫格内广播
function Scene:broadcast9(roleId, msg, id1, id2)
	local obj = self._objList[roleId]
	local sobj = self:getSceneObj(obj._copyId)
	sobj:broadcast9(obj, msg, id1, id2)
end


-- if g_scene == nil then
-- 	g_scene = Scene()
-- end