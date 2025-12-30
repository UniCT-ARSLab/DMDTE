class_name MultiplayerNetwork extends Node

signal twin_spawned(twin: DigitalTwin)

var is_host: bool = false
var peer_id: int:
	get:
		return multiplayer.multiplayer_peer.get_unique_id()
		
var peer: ENetMultiplayerPeer
@export var dtp_network : DTPNetwork #= $"../DTPNetwork"
@export var multiplayer_spawner:MultiplayerSpawner# = $MultiplayerSpawner
@export var twins:Node #= $"../../Twins"



func _ready():
	peer = ENetMultiplayerPeer.new()
	_run_from_cmdline()
	peer.peer_connected.connect(_on_connect)
	peer.peer_disconnected.connect(_on_discconnect)
	
	

func _spawnRemoteTwin(_val : Variant):
	return

func _run_from_cmdline():
	if CmdArgs.has_argument('create-host'):
		var port:int = CmdArgs.get_int('create-host')
		create_host(port)
		print("created host with port: %d" % [port])
		push_warning("i'm server")
	elif CmdArgs.has_argument('connect'):
		var host_port: Array = CmdArgs.get_string('connect').split(':')
		var host: String =  host_port[0]
		var port: int = int(host_port[1])
		create_client(host, port)
		print("created client to: %s:%d" % [host, port])
		push_warning("i'm client")

				
	

func create_client(ipaddr: String, port: int):
	peer.create_client(ipaddr, port)
	multiplayer.multiplayer_peer = peer
	is_host = false

func create_host(port: int):
	peer.create_server(port)
	multiplayer.multiplayer_peer = peer
	is_host = true

func _on_connect(id: int):
	print("[%d] peer %d connected" % [peer_id, id])
	#multiplayer_spawner.spawn_function = _spawnRemoteTwin
	
	#var robot := dtp_network.digitalTwin.instantiate()
	#robot.set_multiplayer_authority(id)
	#robot.name = str(id)
	#dtp_network.spawn_path.add_child(robot, true)

func _on_discconnect(id_peer):
	
	for dt in twins.get_children():
		if dt.get_multiplayer_authority() == id_peer:
			dt.queue_free()
			return
	
@rpc("any_peer","call_remote", "reliable")
func spawn_robot(peer_id_: int, robot_name: String, identification: String, dtp_peer_id: int):

	var robot: DigitalTwin
	if peer_id_ == multiplayer.multiplayer_peer.get_unique_id() : return
	
	if dtp_network.spawn_path.has_node(robot_name):
		print("[%d] prof già ho il mrobottino :c" % multiplayer.multiplayer_peer.get_unique_id())
		robot = dtp_network.spawn_path.get_node(robot_name)
		robot.set_multiplayer_authority(peer_id_)
		robot.ghost.visible = false
		robot.peer_id = dtp_peer_id

		robot.multiplayer_peer_id = peer_id_
		robot.check_remote.call_deferred(true)
		robot.disableProcesses.call_deferred()
		#return
	else:
		
		robot = dtp_network.digitalTwins[identification].instantiate()
		robot.peer_id = dtp_peer_id
		#robot.ghost.visible = false
		robot.name = robot_name
		robot.multiplayer_peer_id = peer_id_
		robot.check_remote.call_deferred(true)
		robot.disableProcesses.call_deferred()
		dtp_network.spawn_path.add_child(robot, true)
		
	twin_spawned.emit(robot)
	
	pass


func _on_multiplayer_spawner_spawned(node):
	print_debug("QUESTO NODO ",multiplayer.multiplayer_peer.get_unique_id(), " vorrebbe spawnare il robot del nodo ", node.multiplayer_peer_id)
	if node.multiplayer_peer_id == multiplayer.multiplayer_peer.get_unique_id():
		node.queue_free()
	pass # Replace with function body.
