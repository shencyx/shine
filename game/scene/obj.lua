require "common"

--场景中能显示的对象类型
OBJ_TYPE = {
	NIL = 0,
	HUMAN = 1
}

--场景中需要显示的对象
Obj = oo.class(nil, "Obj")

function Obj:__init(id)
	self._id = id
	self._objTyep = OBJ_TYPE.NIL
	self._x = 0
	self._y = 0
	self._viewData = nil
end

function Obj:viewData( )
	-- body
end

function Obj:updateView( tbl )
	-- body
end