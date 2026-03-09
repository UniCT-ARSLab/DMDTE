class_name DTPHelloMessage extends DTPMessage

var uuid: String

func _init():
	self.message_type = MessageType.Hello

static func from_bytes(data: PackedByteArray) -> DTPHelloMessage:
	var result:= DTPHelloMessage.new()
	result.uuid = decode_uuid(data.slice(1))
	return result
	
func to_bytes():
	var data := super.to_bytes()
	data.append_array(encode_uuid(uuid))
	data.encode_u16(0, data.size())
	return data
	
static func encode_uuid(uuid: String) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(16)
	var j: = 0
	for i in range(16):
		if not uuid[j].is_valid_hex_number(): j+=1
		if j >= uuid.length(): return PackedByteArray()
		var hi := int(uuid[j])
		var lo := int(uuid[j+1])
		j+=2
		result[i] = (hi << 8) | lo
	return result
	
static func decode_uuid(uuid: PackedByteArray) -> String:
	var result := (
		"%x" % uuid.decode_u8(0) 	+
		"%x" % uuid.decode_u8(1) 	+
		"%x" % uuid.decode_u8(2) 	+
		"%x" % uuid.decode_u8(3) 	+
		"-" 					 	+
		"%x" % uuid.decode_u8(4) 	+
		"%x" % uuid.decode_u8(5) 	+
		"-"							+
		"%x" % uuid.decode_u8(6) 	+
		"%x" % uuid.decode_u8(7) 	+
		"-"							+
		"%x" % uuid.decode_u8(8) 	+
		"%x" % uuid.decode_u8(9)	+
		"-"							+
		"%x" % uuid.decode_u8(10)	+
		"%x" % uuid.decode_u8(11)	+
		"%x" % uuid.decode_u8(12)	+
		"%x" % uuid.decode_u8(13)	+
		"%x" % uuid.decode_u8(14)	+
		"%x" % uuid.decode_u8(15)	
	)
	return result
