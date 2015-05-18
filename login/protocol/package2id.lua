
--协议包对应id
local tbl = {
	login = 1,		--登陆服的协议
}


--
local ret = {}
for k, v in pairs(tbl) do
	ret[k] = v
	ret[v] = k
end
return ret