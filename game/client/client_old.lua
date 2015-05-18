package.cpath = "luaclib/?.so"
package.path = "lualib/?.lua"
package.path = package.path .. ";pj/?.lua";


local socket = require "clientsocket"
local crypt = require "crypt"
local bit32 = require "bit32"


--sproto
local sproto = require "sproto"
local proto = require "protocol.include"

-- local host = sproto.new(proto.s2c):host "package"
-- local request = host:attach(sproto.new(proto.c2s))
local sp = sproto.new(proto)
local host = sp:host "package"
local request = host:attach(sp)

local fd = assert(socket.connect("127.0.0.1", 8001))

local function writeline(fd, text)
	socket.send(fd, text .. "\n")
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
		local result
		result, last = f(last)
		if result then
			return result, last
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

	return function()
		while true do
			local result
			result, last = try_recv(fd, last)
			if result then
				return result
			end
			socket.usleep(100)
		end
	end
end

local readline = unpack_f(unpack_line)

local challenge = crypt.base64decode(readline())

local clientkey = crypt.randomkey()
writeline(fd, crypt.base64encode(crypt.dhexchange(clientkey)))
local secret = crypt.dhsecret(crypt.base64decode(readline()), clientkey)

print("sceret is ", crypt.hexencode(secret))

local hmac = crypt.hmac64(challenge, secret)
writeline(fd, crypt.base64encode(hmac))

local token = {
	server = "sample",
	user = "hello",
	pass = "password",
}

local function encode_token(token)
	return string.format("%s@%s:%s",
		crypt.base64encode(token.user),
		crypt.base64encode(token.server),
		crypt.base64encode(token.pass))
end

local etoken = crypt.desencode(secret, encode_token(token))
local b = crypt.base64encode(etoken)
writeline(fd, crypt.base64encode(etoken))

local result = readline()
print(result)
local code = tonumber(string.sub(result, 1, 3))
assert(code == 200)
socket.close(fd)

local subid = crypt.base64decode(string.sub(result, 5))

print("login ok, subid=", subid)

----- connect to game server

local function send_request(v, session)
	local size = #v + 4
	local package = string.char(bit32.extract(size,8,8))..
		string.char(bit32.extract(size,0,8))..
		v..
		string.char(bit32.extract(session,24,8))..
		string.char(bit32.extract(session,16,8))..
		string.char(bit32.extract(session,8,8))..
		string.char(bit32.extract(session,0,8))

	socket.send(fd, package)
	return v, session
end

local function recv_response(v)
	local content = v:sub(1,-6)
	local ok = v:sub(-5,-5):byte()
	local session = 0
	for i=-4,-1 do
		local c = v:byte(i)
		session = session + bit32.lshift(c,(-1-i) * 8)
	end
	return ok ~=0 , content, session
end

local function unpack_package(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, text
	end

	return text:sub(3,2+s), text:sub(3+s)
end

local readpackage = unpack_f(unpack_package)

local function send_package(fd, pack)
	local size = #pack
	local package = string.char(bit32.extract(size,8,8))..
		string.char(bit32.extract(size,0,8))..
		pack

	socket.send(fd, package)
end

local text = "echo"
local index = 1

-- print("connect")
-- local fd = assert(socket.connect("127.0.0.1", 8888))
-- last = ""

-- local handshake = string.format("%s@%s#%s:%d", crypt.base64encode(token.user), crypt.base64encode(token.server),crypt.base64encode(subid) , index)
-- local hmac = crypt.hmac64(crypt.hashkey(handshake), secret)


-- send_package(fd, handshake .. ":" .. crypt.base64encode(hmac))

-- print(readpackage())
-- print("===>",send_request(text,0))
-- -- don't recv response
-- -- print("<===",recv_response(readpackage()))

-- print("disconnect")
-- socket.close(fd)

index = index + 1

print("connect again")
local fd = assert(socket.connect("127.0.0.1", 8888))
last = ""

local handshake = string.format("%s@%s#%s:%d", crypt.base64encode(token.user), crypt.base64encode(token.server),crypt.base64encode(subid) , index)
local hmac = crypt.hmac64(crypt.hashkey(handshake), secret)

send_package(fd, handshake .. ":" .. crypt.base64encode(hmac))

--print(readpackage()) 
local code, result = readpackage()
print("code", code, "result", result)


-- print("===>",send_request("fake",1))	-- request again (use last session 0, so the request message is fake) 
-- print("===>",send_request("again",2))	-- request again (use new session) 
-- print("<===",recv_response(readpackage()))
-- print("<===",recv_response(readpackage()))\



local function send_package(fd, pack)
	local size = #pack
	local package = string.char(bit32.extract(size,8,8)) ..
		string.char(bit32.extract(size,0,8))..
		pack

	socket.send(fd, package)
end

local function unpack_package(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, text
	end

	return text:sub(3,2+s), text:sub(3+s)
end

local function recv_package(last)
	local result
	result, last = unpack_package(last)
	if result then
		return result, last
	end
	local r = socket.recv(fd)

	if not r then
		return nil, last
	end
	print("socket recv :", r)
	if r == "" then
		error "Server closed"
	end
	return unpack_package(last .. r)
end

local session = 0

local function send_request(name, args)
	session = session + 1
	local str = request(name, args, session)
	send_package(fd, str)
	--print("Request:", session, string.byte(str, 1, string.len(str)))
end

local last = ""

local function print_request(name, args)
	print("REQUEST", name)
	if args then
		for k,v in pairs(args) do
			print(k,v)
		end
	end
end

local function print_response(session, args)
	print("RESPONSE", session)
	if args then
		for k,v in pairs(args) do
			print(k,v)
		end
	end
end

local function print_package(t, ...)
	if t == "REQUEST" then
		print_request(...)
	else
		assert(t == "RESPONSE")
		print_response(...)
	end
end

local function dispatch_package()
	while true do
		local v
		v, last = recv_package(last)
		if not v then
			break
		end

		print_package(host:dispatch(v))
	end
end

send_request("post_handshanke", {msg="what a good day!"})
send_request("get", { what = "hello" })
send_request("handshake")
send_request("set", { what = "hello", value = "world" })


while true do
	dispatch_package()
	-- local cmd = socket.readstdin()
	-- if cmd then
	-- 	send_request("get", { what = cmd })
	-- else
	-- 	socket.usleep(100)
	-- end
end



print("disconnect")
socket.close(fd)

