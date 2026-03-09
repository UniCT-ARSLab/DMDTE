class_name DTPDataMessage extends DTPMessage

var fields: Dictionary[int, PackedByteArray]

func _init():
	self.message_type = MessageType.Data

func to_bytes() -> PackedByteArray:
	var data := super.to_bytes()
	
	var payload_size:= 1
	for index in fields:
		payload_size+= 2 + fields[index].size()
	data.resize(data.size() + payload_size)
	var offs:= 3
	data.encode_u8(offs, fields.size()); offs+=1
	for index in fields:
		var value:= fields[index]
		data.encode_u8(offs, index); offs+=1
		data.encode_u8(offs, value.size()); offs+=1
		for byte in value:
			data.encode_u8(offs, byte); offs+=1
	return data
	
static func from_bytes(data: PackedByteArray) -> DTPDataMessage:
	var fields_count:= data.decode_u8(1)
	var offset:= 2
	var dict: Dictionary[int, PackedByteArray] = {}
	for i in range(fields_count):
		var index := data.decode_u8(offset); offset+=1
		var size  := data.decode_u8(offset); offset+=1
		var fdata := data.slice(offset, offset + size); offset+= size
		dict[index] = fdata
	var result:= DTPDataMessage.new()
	result.fields = dict
	return result
