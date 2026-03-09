class_name DTPPingMessage extends DTPMessage


func _init() -> void:
	self.message_type = MessageType.Ping

static func from_bytes(data: PackedByteArray) -> DTPMessage:
	return DTPPingMessage.new()
	
