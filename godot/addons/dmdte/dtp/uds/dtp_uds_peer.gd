class_name UDSDTPPeer extends DTPPeer2

var stream: StreamPeerUDS

func _process(delta: float) -> void:
	var errored = stream.get_status() == StreamPeerSocket.STATUS_ERROR || stream.get_status() == StreamPeerSocket.STATUS_NONE
	if errored:
		return queue_free()
  
	while stream.get_available_bytes() > 0:
		var size: = stream.get_16()
		var payload = stream.get_data(size - 2)[1]
		print_debug("Received %d bytes" % size)
		print(payload)
