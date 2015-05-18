
local serviceName = ...
local pb = require "protobuf"
pb.register_file "pj/protocol/util.pb"

local package2id = require "package2id"
local tbl = {}
tbl._regFunc = {}	--注册协议函数
local require_o = require
local function require( fileName )
	--注册自动生成的lua脚本,邦定pb名与id
	local pb2id = require_o(fileName.."_pb2id")
	local fid = package2id[pb2id.package]
	assert(tbl[fid] == nil)
	tbl[fid] = pb2id
	--注册 *.pb 文件
	local pbFile = "pj/protocol/"..fileName..".pb"
	pb.register_file(pbFile)
end

--include 所有协议文件	[一级消息id]
for k, v in pairs(package2id) do
	if type(k) == "string" then
		require(k)
	end
end


--require "base"			-- 1

local ID_SIZE = 256
local cache = {}
function tbl:getPb(id1, id2)
	local id = id1 * ID_SIZE + id2
	if cache[id] ~= nil then
		return cache[id]
	end
	local pb = self[id1]
	if pb == nil then
		return nil
	end
	local pbName = pb.package.."."..pb[id2]
	cache[id] = pbName
	return pbName
end

function tbl:getId(package, message)
	local id1 = package2id[package]
	local pb = self[id1]
	local id2 = pb[message]
	return id1, id2
end

function tbl:registFunc(id1, id2, func)
	if (type(id1) == "string") then
		id1, id2 = self:getId(id1, id2)
	end
	local id = id1 * ID_SIZE + id2
	self._regFunc[id] = func
end

function tbl:getFunc(id1, id2)
	local id = id1 * ID_SIZE + id2
	return self._regFunc[id]
end

function tbl:pack(msg, id1, id2)
	local pbName
	if type(id1) == "string" then
		pbName = id1.."."..id2
		id1, id2 = self:getId(id1, id2)
	else
		pbName = self:getPb(id1, id2)
	end
	local strBuf = pb.encode(pbName, msg)
	local size = 2 + #strBuf
	local buf = string.pack(">I2", size)..string.pack(">I1", id1)..string.pack(">I1", id2)..strBuf
	return buf, size
end

local unpack = string.unpack
function tbl:unpack( msgBuf, sz )
	--1字节一级id,1字节二级id,剩下的为pb数据流
	local id1, id2, pbBuf = unpack(">I1>I1c"..(sz-2), msgBuf)
	local pbName = self:getPb(id1, id2)
	assert(pbName, string.format("unknow protocol:%d, %d", id1, id2))
	local msg = pb.decode(pbName, pbBuf)
	return msg, id1, id2
end

function tbl:dispatch(user, msgBuf, sz )
	local msg, id1, id2 = self:unpack( msgBuf, sz )
	local func = self:getFunc(id1, id2)
	assert(func, string.format("dispatch invalid protocol:%d, %d", id1, id2))
	return func(user, msg)
end

--全局类
protMgr = tbl

return tbl