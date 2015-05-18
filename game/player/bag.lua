require "common"
--local skynet = require "skynet"


Bag = oo.class(nil, "Bag")

function Bag:__init()
	self._maxSize = 50
	self._size = 0
end