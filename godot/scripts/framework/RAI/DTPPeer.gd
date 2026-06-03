class_name DTPPeer extends Node

enum MessageType {
	Call = 0,
	Update = 1,
	Identify = 2
}

signal on_connect(dtpm: DTPPeer)
signal on_disconnect(dtpm: DTPPeer)
signal on_update(dtpm: DTPPeer, update: Dictionary)

@export var updateInterval: float = 1.0/20.0

var _updateIntervalTicks: float = 0

var peer: ENetPacketPeer
var peerId: int
var _state: Dictionary = {}

var _property_queue: Dictionary = {}
var _rpc_queue: Dictionary = {}


var _num_packets_received: float = 0
var _num_packets_sent: float = 0
var _num_packets_dt_acc: float = 0.0

var peer_address: String:
	get:
		return peer.get_remote_address()


var is_active: bool:
	get:
		return peer != null && peer.is_active()

@export var ghost: DigitalGhost
@export var properties: Array[DTPProperty]
@export var methods: Array[DTPMethod]


var prop_index_dict: Dictionary[int, DTPProperty]
var prop_name_dict: Dictionary[String, DTPProperty]
var meth_index_dict: Dictionary[int, DTPMethod]
var meth_name_dict: Dictionary[String, DTPMethod]

func _init() -> void:
	pass
func _ready() -> void:
	_reset_mappings()
	# 'owner' is the root node of the child scene the node is child of
	owner.set_meta("DTPPeer", self)
	#ghost.dtp_peer = self
	
func _reset_mappings() -> void:
	prop_index_dict = {}
	prop_name_dict = {}
	meth_name_dict = {}
	meth_index_dict = {}
	for prop in properties:
		prop_index_dict[prop.index] = prop
	for prop in properties:
		prop_name_dict[prop.name] = prop
	for meth in methods:
		meth_index_dict[meth.index] = meth
	for meth in methods:
		meth_name_dict[meth.name] = meth
		

func accept_peer(peer_: ENetPacketPeer, peerId_: int):
	self.peer = peer_
	self.peerId = peerId_
	on_connect.emit(self)

func peer_disconnected():
	on_disconnect.emit(self)


func _process(dt: float) -> void:
	if is_active:
		_service(dt)
		_updateIntervalTicks+= dt
		if _updateIntervalTicks > updateInterval:
			_updateIntervalTicks = 0
			_flush_update_queue()
			_flush_rpc_queue()
		
		if _num_packets_dt_acc > 1.0:
			# print_debug("received: {0}\tsent: {1}".format([_num_packets_received, _num_packets_sent]))
			_num_packets_dt_acc = 0.0
			_num_packets_received = 0
			_num_packets_sent = 0
		_num_packets_dt_acc+=dt
		
	
func _service(_dt: float) -> void:
	while peer.get_available_packet_count() > 0:
		var packet: PackedByteArray = peer.get_packet()
		_num_packets_received+=1
		var it: int = 0
		
		var msgty: int = packet.decode_u8(it); it+=1
		match msgty:	
			MessageType.Update:
				_handle_update(packet, it)
				pass
			MessageType.Call:
				_handle_call(packet, it)
			MessageType.Identify:
				push_warning("Ignored Identify packet.")
	
func _handle_call(packet: PackedByteArray, it: int) -> int:
	var method_index: int = packet.decode_u8(it); it+=1
	var payload_size: int = packet.decode_u16(it); it+=2

	if not ghost:
		push_warning("No ghost available to process RPC call")
	elif method_index in self.meth_index_dict:
		var desc := self.meth_index_dict[method_index]
		if desc.name in ghost and ghost[desc.name] is Callable:
			var method: Callable = ghost[desc.name]
			var params = []
			var jt:= it
			for i in range(len(desc.args)):
				var ty: Types.Type = desc.args[i]
				var ty_size: int = Types.sizeof(ty)
				var slice:= packet.slice(jt, jt + ty_size); jt+= ty_size
				params.append(Types.decode(slice, ty))
			
			method.callv(params)
		else:
			push_warning("Ghost has no ghost corresponding method, couldn't invoke RPC call")
	else:
		push_warning("No ghost available to invoke RPC call")
	return it + payload_size

func _handle_update(packet: PackedByteArray, it: int) -> int:
	var update: Dictionary = {}
	var number_of_properties: int = packet.decode_u8(it); it+=1
	for i in range(number_of_properties):
		var index: int = packet.decode_u8(it); it+=1
		var size: int = packet.decode_u8(it); it+=1
		
		if index in prop_index_dict:
			var property: DTPProperty = self.prop_index_dict[index]
			it = _parse_property(packet, property, size, update, it)
		else:
			it+=size
	self._accept_update(update)
	return it

func _accept_update(update: Dictionary):
	for key in update.keys():
		_state[key] = update[key]
	if ghost:
		_update_ghost(update)
	self.on_update.emit(self, update)

func _update_ghost(update: Dictionary):
	for key in update.keys():
		if key in ghost:
			ghost[key] = update[key]

func _parse_property(packet: PackedByteArray, prop: DTPProperty, size: int, update: Dictionary, it: int) -> int:
	update[prop.name] = Types.decode(packet.slice(it, it + size), prop.type)
	it+=size
	return it
	


func get_property(name_: String):
	return _state[name_]


func set_property(name_: String, value: Variant) -> int:
	if !is_active:	
		push_error("Peer's dead m8!")
		return -1
	if !prop_name_dict.has(name_):
		push_error("Property not not found!")
		return -1
	var prop: DTPProperty = prop_name_dict[name_]
	var data = PackedByteArray()
	data.resize(2)
	data.append_array(Types.encode(value, prop.type))
	data.encode_u8(0, prop.index)
	data.encode_u8(1, data.size() - 2)
	_property_queue[name_] = data
	return 0


func _flush_rpc_queue():
	for rpc_call in _rpc_queue.values():
		
		peer.send(0, rpc_call, ENetPacketPeer.FLAG_RELIABLE)
	_num_packets_sent+=_rpc_queue.size()
	_rpc_queue.clear()

func _flush_update_queue():
	# no need to test is_active as it's called if is_active is true
	var number_of_properties: int = _property_queue.size()
	if number_of_properties == 0: return
	var payload: PackedByteArray = PackedByteArray()
	payload.resize(2)
	payload.encode_u8(0, 1)
	payload.encode_u8(1, number_of_properties)
	
	for prop in _property_queue.values():
		payload.append_array(prop)
	_property_queue.clear()
	
	peer.put_packet(payload)
	
	_num_packets_sent+=_rpc_queue.size()

	
func call_method(name_: String, params: Array) -> int:
	if !is_active:
		return -1
		#push_error("Peer's dead m8!")
		#return -1
	if !meth_name_dict.has(name_):
		push_error("Method not not found!")
		return -1
	var desc: DTPMethod = meth_name_dict[name_]
	if len(params) != len(desc.args):
		push_error("Invalid number of parameters")
		return -1
	var payload = PackedByteArray()
	payload.resize(4)
	payload.encode_u8(0, MessageType.Call)
	payload.encode_u8(1, desc.index)
	for i in range(len(params)):
		var ty: Types.Type = desc.args[i]
		var param = params[i]
		payload.append_array(Types.encode(param, ty))
	payload.encode_u16(2, len(payload) - 4)
	#peer.send(0, payload, ENetPacketPeer.FLAG_RELIABLE)
	_rpc_queue[name_] = payload
	return 0
