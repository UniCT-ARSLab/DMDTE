class_name DTPMessage extends RefCounted

enum MessageType {
	Ping = 0,
	Hello = 1,
	Data = 2,
	Action = 3,
	Invalid = -1
}
var message_type: MessageType

static func from_bytes(data: PackedByteArray) -> DTPMessage:
	var msgty = data.decode_u8(0)
	match msgty:
		0: return DTPPingMessage.from_bytes(data)
		1: return DTPHelloMessage.from_bytes(data)
		2: return DTPDataMessage.from_bytes(data)
		3: return DTPActionMessage.from_bytes(data)
		_: 
			push_error("Invallid message type: %d" & msgty)
			var result:= DTPMessage.new()
			result.message_type = MessageType.Invalid
			return result

func to_bytes() -> PackedByteArray:
	var message:= PackedByteArray()
	message.resize(3)
	message.encode_u16(0, message.size())
	message.encode_u8(2, message_type)
	return message
	
