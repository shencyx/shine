
--协议包对应id
local tbl = {
	login = 1,		--登陆服的协议
	base = 2,		--基本信息和场景
	bag = 3,		--背包
}


--
local ret = {}
for k, v in pairs(tbl) do
	ret[k] = v
	ret[v] = k
end
return ret