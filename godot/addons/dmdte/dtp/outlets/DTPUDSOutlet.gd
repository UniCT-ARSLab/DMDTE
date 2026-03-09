class_name DTPUDSOutlet extends DTPOutlet

@export var path: String
var _server: UDSServer = UDSServer.new()
var _conns: Array[StreamPeerUDS] = []

func _ready() -> void:
	super._ready()
	if auto_start:
		self.begin()

func _cleanup():
	if _server.is_listening():
		_server.stop()
	
func begin():
	if _server.is_listening(): return
	var err:= _server.listen(self.path)
	if err:
		push_error(err);
		return err

func _take_connections():
	while _server.is_listening():
		var conn:= _server.take_connection()
		if not conn: break
		conn.put_data(DTPPingMessage.new().to_bytes())
		_conns.append(conn)

func _process_connections():
	for conn in _conns:
		while conn.get_available_bytes() > 0:
			var size:= conn.get_16() - 2
			var data:= conn.get_data(size)[1] as PackedByteArray
			var message:= DTPMessage.from_bytes(data)
			process_message(conn, message)
			
func _process(delta_: float) -> void:
	_process_connections()
	_take_connections()
	
func dispatch(peer: DTPPeer2, message: DTPMessage) -> Error:
	var handle:= peer.handle
	if handle is  StreamPeerUDS:
		handle.put_data(message.to_bytes())
		return Error.OK
	return Error.FAILED
