--package.path = package.path .. ";../?.lua"
--require("protocol_router")
--require("generate_config")

local name = ...
local fileName = name..".proto"
local outName = name.."_pb2id.lua"


local package = nil
local operId = 1
local pb2id = {}
local id2pb = {}

function parse()
	local file = io.open(fileName, "r")
	local line = file:read()

	local lineN = 1
	while line do
		local endPos = string.find(line, "//")
		if endPos then
			line = string.sub(line, 1, endPos - 1)
		end
		--print(line)
		local ret = parseLine(line)
		assert(0 == ret, string.format("something error in line:%d, code:%d", lineN, ret))
		
		line = file:read()
		lineN = lineN + 1
	end
	file:close()
end

function parseLine(line)
	local tag = {}
	for w in string.gmatch(line, "%a+[%._]?%a+") do
		table.insert(tag, w)
	end

	if tag[1] == "package" then
		package = tag[2]
	elseif tag[1] == "message" then
		local key = tag[2]
		pb2id[key] = operId
		id2pb[operId] = key
		operId = operId + 1
	end

	return 0
end

function save()
	
	outFile = io.open(outName, "w")
	outFile:write("\n\n")
	outFile:write("local tbl = {\n")
	for k, v in pairs(id2pb) do
		local str = "\t["..k.."] = '"..v.."',\n"
		outFile:write(str)
	end
	for k, v in pairs(pb2id) do
		local str = "\t"..k.." = "..v..",\n"
		outFile:write(str)
	end
	outFile:write("\tpackage = '"..package.."',\n")
	outFile:write("}\n\n")
	outFile:write("return tbl")
	outFile:write("\n")
	outFile:close()
end

function start()
	parse()
	print(">>> package:", package)
	save()
	
end

start()
