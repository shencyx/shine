protoc -o util.pb util.proto
protoc -o base.pb base.proto
protoc -o bag.pb bag.proto
protoc -o login.pb login.proto 


lua generate_pb2id.lua base
lua generate_pb2id.lua bag
lua generate_pb2id.lua login

pause