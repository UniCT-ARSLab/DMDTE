class_name DTPSynchronizer
extends Node

@export var uuid: String
@export var server: DTPServer
@export var config: DTPSynchronizerConfig

var peer: DTPPeer2
signal connection_state_change(connected: bool)

var is_connected: bool:
	get: return peer != null
	
var enabled: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not server: server = DTPGlobalServer
	server.connected.connect(_accept)
	server.disconnected.connect(_accept)

func _accept(peer: DTPPeer2):
	if is_connected: return
	if peer.uuid == self.uuid:
		print_debug("Accepted!!!")
		self.peer = peer
		self.connection_state_change.emit(true)
		peer.message.connect(_on_message)

func _unaccept(peer: DTPPeer2):
	if is_connected and peer == self.peer:
		peer.message.disconnect(_on_message)
		self.connection_state_change.emit(false)
		self.peer = null

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_message(message: DTPMessage):
	if message is DTPDataMessage:
		_on_message_process_data(message)
	if message is DTPActionMessage:
		_on_message_process_action(message)

func _on_message_process_data(message: DTPDataMessage):
	pass
func _on_message_process_action(message: DTPActionMessage):
	pass
	
