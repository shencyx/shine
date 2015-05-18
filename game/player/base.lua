require "common"
--local skynet = require "skynet"


Base = oo.class(nil, "Base")

function Base:__init()
	self._sceneId = nil
	self._lastId = nil
	self._copyId = nil
	self._x = 0
	self._y = 0
end

function Base:view( )
	
end

function Base:autoMove( )
	self._x = self._x + 50
end