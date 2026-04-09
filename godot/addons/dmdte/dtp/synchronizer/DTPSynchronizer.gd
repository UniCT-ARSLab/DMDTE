class_name DTPSynchronizer
extends Node

@export var uuid: String
@export var server: DTPServer
@export var replication: Dictionary[String, DTPReplication]
@export var config: DTPSynchronizerConfig:
	get:
		return _config
	set(conf):
		self._config = conf
		self.index_to_prop = {}
		self.index_to_action = {}
		self.string_to_prop = {}
		self.string_to_action = {}
		for prop in conf.properties:
			self.index_to_prop[prop.index] = prop
			self.string_to_prop[prop.name] = prop
		for action in conf.actions:
			self.index_to_action[action.action_id] = action
			self.string_to_action[action.name] = action
			
		if self.replication:
			_build_index_to_replication()
	

var _config: DTPSynchronizerConfig
var peer: DTPPeer2
signal connection_state_change(connected: bool)
signal properties_change(properties: Dictionary[String, Variant])
signal action(action: String, action_id: int, payload: Variant)


var is_connected: bool:
	get: return peer != null

var index_to_prop: Dictionary[int, DTPProperty]
var index_to_action: Dictionary[int, DTPAction]
var string_to_prop: Dictionary[String, DTPProperty]
var string_to_action: Dictionary[String, DTPAction]
var index_to_replication: Dictionary[int, Array]

var enabled: bool = false

func _build_index_to_replication():
	self.index_to_replication = {}
	if not self._config: return
	if not self.replication: return
	
	for prop in self._config.properties:
		var name:= prop.name
		var index:= prop.index
		var array: Array[NodePath] = []
		if not name in self.replication: continue
		for path in self.replication[name].paths:
			array.append(path)
		self.index_to_replication[index] = array

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not server: server = DTPGlobalServer
	server.connected.connect(_accept)
	server.disconnected.connect(_accept)
	
	self.properties_change.connect(print_debug)

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
	var properties: Dictionary[String, Variant] = {}
	for index in message.fields:
		var data:= message.fields[index]
		if not index in index_to_prop: continue
		var prop:= index_to_prop[index]
		var value = Types.decode(data, prop.type)
		properties[prop.name] = value
		
		if index in self.index_to_replication:
			for path in index_to_replication[index]:
				if not has_node(path): 
					push_warning("Path not found {}".format([path]))
					continue
				var node = get_node(path)
				var prop_path:= NodePath(path.get_concatenated_subnames())
				node.set_indexed(prop_path, value)

	self.properties_change.emit(properties)

func _on_message_process_action(message: DTPActionMessage):
	var action_id:= message.action_id
	if not action_id in index_to_action: return
	var action := index_to_action[action_id]

	var payload:= message.data

	self.action.emit(action.name, action_id, payload)
	

func dispatch(action_name: String, payload: Variant):
	if not is_connected: return
	if not action_name in string_to_action: return
	var action := string_to_action[action_name]
	var message:= DTPActionMessage.new()
	message.action_id = action.action_id
	if payload is PackedByteArray:
		message.data = payload
	else:
		pass
	
	peer.dispatch(message)
	
