protoc -o util.pb util.proto
protoc -o login.pb login.proto 

lua generate_pb2id.lua login

pause