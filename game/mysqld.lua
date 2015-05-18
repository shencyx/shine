require "common"
local skynet = require "skynet"
local mysql = require "mysql"


function init(...)
	print ("mysqld server start:", ...)
	db = mysql.connect{	
		host="127.0.0.1",
		port=3306,
		database="ddz_test",
		user="root",
		password="123456",
		max_packet_size = 1024 * 1024
	}
	if not db then
		print("failed to connect")
	end
-- You can return "queue" for queue service mode
--	return "queue"
end

function exit(...)
	print ("mysqld server exit:", ...)
end

function response.error()
	error "throw an error"
end

function accept.exec(sql)
	print("mysqld exex!", sql)
	local res =  db:query(sql)
	if res.err then
		skynet.error("errno:", res.errno, res.err)
	end
end

function response.query(sql)
	print("mysqld query!", sql)
	local res = db:query(sql)
	--print_r(res)
	return res
end