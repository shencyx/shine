require "common"
require "obj"


--场景中的人物对象
HumanObj = oo.class(Obj, "HumanObj")

function HumanObj:__init(id)
	Obj.__init(self, id)
	self._objTyep = OBJ_TYPE.HUMAN
end