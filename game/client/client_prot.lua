local socket = require "clientsocket"
local pb = require "protobuf"
pb.register_file "pj/protocol/login.pb"
pb.register_file "pj/protocol/base.pb"
pb.register_file "pj/protocol/bag.pb"

local function writeline(fd, text)
	socket.send(fd, text .. "\n")
end

local function send_pb(fd, pb_type, pb_table, id1, id2)
	local stringbuffer = pb.encode(pb_type, pb_table)
	local size = 2 + #stringbuffer
	local package = string.pack(">I2", size)..string.pack(">I1", id1)..string.pack(">I1", id2)..stringbuffer
	print("send_pb", size)
	socket.send(fd, package)
end

local function unpack_line(text)
	local from = text:find("\n", 1, true)
	if from then
		return text:sub(1, from-1), text:sub(from+1)
	end
	return nil, text
end

local last = ""

local function unpack_f(f)
	local function try_recv(fd, last)
		local result, size
		result, last, size = f(last)
		if result then
			return result, last, size
		end
		local r = socket.recv(fd)
		if not r then
			return nil, last
		end
		if r == "" then
			error "Server closed"
		end
		return f(last .. r)
	end

	return function(fd)
		while true do
			local result, size
			result, last, size = try_recv(fd, last)
			if result then
				return result, size
			end
			socket.usleep(100)
		end
	end
end

local readline = unpack_f(unpack_line)

local function unpack_package(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, text
	end

	return text:sub(3,2+s), text:sub(3+s), s
end

local readpackage = unpack_f(unpack_package)

local function read_pb(fd, pb_name)
	local package_buf, size = readpackage(fd)
	local pb_package, pb_msg, pb_buf = string.unpack(">I1>I1c"..(size-2), package_buf)
	if pb_name ~= nil then
		return pb.decode(pb_name, pb_buf)
	else
		return pb_package, pb_msg, pb_buf
	end
end

local tbl = {}
tbl.read_pb = read_pb
tbl.send_pb = send_pb
tbl.last = last

return tbl