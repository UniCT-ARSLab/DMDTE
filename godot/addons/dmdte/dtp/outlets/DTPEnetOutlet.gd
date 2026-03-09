class_name DTPEnetOutlet extends DTPOutlet

const UNRELIABLE_CHANNEL: int = 0
const RELIABLE_CHANNEL: int = 1

@export var bind_address: String = "127.0.0.1"
@export var port: int = 24500
@export var max_peers: int = 32
var _host: ENetConnection = ENetConnection.new()
var _conns: Array[ENetPacketPeer] = []
var _is_listening := false

func _ready() -> void:
	super._ready()
	if auto_start:
		self.begin()

func _cleanup():
	if _is_listening:
		_host.destroy()
		_is_listening = false
	
func begin() -> Error:
	if _is_listening: return Error.OK
	var err:= _host.create_host_bound(bind_address, port, max_peers)
	if err:
		push_error(err);
		return err
	_is_listening = true
	return Error.OK


func _process(delta_: float) -> void:
	_service()
	
func _service():
	while _is_listening:
		var service := _host.service()
		var evty := service[0] as ENetConnection.EventType
		var peer := service[1] as ENetPacketPeer
		match evty:
			ENetConnection.EVENT_CONNECT:
				peer.send(RELIABLE_CHANNEL, DTPPingMessage.new().to_bytes(), peer.FLAG_RELIABLE)
			ENetConnection.EVENT_RECEIVE:
				while peer.get_available_packet_count() > 0:
					var message := DTPMessage.from_bytes(peer.get_packet().slice(2))
					process_message(peer, message)
			ENetConnection.EVENT_DISCONNECT:
				push_error("Disconnection not yet handled!")
			ENetConnection.EVENT_ERROR:
				push_error("Received error!")
			ENetConnection.EVENT_NONE:
				return
				
	
func dispatch(peer: DTPPeer2, message: DTPMessage) -> Error:
	var handle:= peer.handle
	if handle is  StreamPeerUDS:
		handle.put_data(message.to_bytes())
		return Error.OK
	return Error.FAILED
