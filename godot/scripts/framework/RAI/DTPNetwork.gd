class_name DTPNetwork extends Node
		

signal on_digital_twin_spawn(instance:DigitalTwin)

@export var digitalTwins: Dictionary[String, PackedScene]

@export var host_address: String = "0.0.0.0"
@export var host_port: int = 25666
@export var auto_init: bool = true
@export var spawn_path: Node

var host: ENetConnection
var instanced_peers: Dictionary[int, DigitalTwin] = {}
@onready var multiplayer_network = $"../MultiplayerNetwork"
@onready var multiplayer_spawner = $"../MultiplayerNetwork/MultiplayerSpawner"
@onready var root = $"../.."


func _ready() -> void:
	if auto_init:
		initialize_server()

func _process(_delta: float) -> void:
	if host != null:
		_service()

func _service() -> void:
	while true:
		var event: Array = host.service()
		var event_ty: ENetConnection.EventType = event[0]
		if multiplayer.is_server():
			pass
		match event_ty:
			ENetConnection.EVENT_CONNECT:
				_handle_connect(event)
			ENetConnection.EVENT_DISCONNECT:
				push_warning("ENetConnection.EVENT_DISCONNECT received on %d" % [event[0]])
				
				_handle_disconnect(event)
			ENetConnection.EVENT_RECEIVE:
				_handle_receive(event)
			ENetConnection.EVENT_ERROR:
				push_error("Got [ENetConnection.EVENT_ERROR]" )
			ENetConnection.EVENT_NONE:
				break

func initialize_server():
	host = ENetConnection.new()
	var port :int =  CmdArgs.get_int('dtp-port', self.host_port)
	
	print_debug("porta: %d" % port)
	var error: Error = host.create_host_bound(host_address, port)
	if error:
		host = null
		push_error("M8 we got an error: %s" % error_string(error))
		return error
	return null

func deinitialize_server():
	host.destroy()
	host = null
	
func _handle_receive(event: Array):
	var peer: ENetPacketPeer = event[1]
	var peer_id: int = peer.get_meta("peer_id")
	if not peer_id in instanced_peers:
		_handle_receive_identification(peer, peer_id)
	
func _handle_receive_identification(peer: ENetPacketPeer, peer_id: int):
	while peer.get_available_packet_count() > 0:
		var packet := peer.get_packet()
		if packet.decode_u8(0) == DTPPeer.MessageType.Identify:
			var identification: String = packet.slice(1).get_string_from_utf8()
			if identification in digitalTwins:
				_spawn_digital_twin(identification, peer, peer_id)
			else:
				push_warning("Unknown agent identification: \"%s\"" % identification)
				peer.peer_disconnect(-1)
				
func _spawn_digital_twin(identification: String, peer: ENetPacketPeer, peer_id: int):
	var digitalTwinScene: PackedScene = self.digitalTwins[identification]
	
	if instanced_peers.has(peer_id):
		disconnect_dtp_peer(peer_id)
	
	
	var instance : DigitalTwin = digitalTwinScene.instantiate()
	instance.set_meta("identification", identification)
	instance.name = instance.name + "[%d]" % [peer_id]
	instance.accept_peer.call_deferred(peer, peer_id)
	instance.peer_id = peer_id
	instance.isRemote = false
	instance.multiplayer_peer_id = multiplayer.multiplayer_peer.get_unique_id()
	
	spawn_path.add_child(instance, true)
	on_digital_twin_spawn.emit(instance)
		
	instanced_peers[peer_id] = instance

	multiplayer_network.spawn_robot.rpc(
		multiplayer.multiplayer_peer.get_unique_id(), 
		instance.name,
		identification,
		peer_id
	)
	
func _handle_connect(event: Array):
	var peer: ENetPacketPeer = event[1]
	var peer_id: int = event[2]
	
	peer.set_meta("peer_id", peer_id)
	if instanced_peers.has(peer_id):
		var identification :String = instanced_peers[peer_id].get_meta("identification")
		_spawn_digital_twin(identification, peer, peer_id)
	
	
func _handle_disconnect(event: Array):
	var enet_peer: ENetPacketPeer = event[1]
	var peer_id: int = enet_peer.get_meta('peer_id')
	push_warning("_handle_disconnect called on %d" % [peer_id])
	if instanced_peers.has(peer_id) and not enet_peer.is_active():
		disconnect_dtp_peer(peer_id)

func disconnect_dtp_peer(peer_id: int):
	push_warning("disconnect_dtp_peer called on %d" % [peer_id])
	var digital_twin: DigitalTwin = instanced_peers[peer_id] 
	instanced_peers.erase(peer_id)
	
	digital_twin.dtp_peer.peer.peer_disconnect_now()
	digital_twin.despawn_dt.rpc()
		

func _exit_tree() -> void:
	deinitialize_server()
