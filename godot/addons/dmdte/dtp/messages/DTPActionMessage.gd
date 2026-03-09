class_name DTPActionMessage extends DTPMessage

var action_id: int
var data: PackedByteArray

func _init() -> void:
	message_type = MessageType.Action

func to_bytes() -> PackedByteArray:
	var buff := super.to_bytes()
	buff.resize(buff.size() + 4)
	buff.encode_u32(3, action_id)
	buff.append_array(data)
	return data
	
static func from_bytes(data: PackedByteArray) -> DTPActionMessage:
	var result := DTPActionMessage.new()
	result.action_id = data.decode_u32(3)
	result.data = data.slice(7)
	return result
