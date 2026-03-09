class_name DTPServer
extends Node

var peers: Node

signal connected(peer: DTPPeer2)
signal disconnected(peer: DTPPeer2)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	peers = Node.new()
	peers.name = "peers"
	add_child(peers, true)

func process_message(outlet: DTPOutlet, handle: RefCounted, message: DTPMessage):
	match message.message_type:
		DTPMessage.MessageType.Ping:
			push_warning("Received PING message! WTF!!!")
		DTPMessage.MessageType.Hello:
			_process_hello(outlet, handle, message)
		DTPMessage.MessageType.Data:
			_process_message(outlet, handle, message)
		DTPMessage.MessageType.Action:
			_process_message(outlet, handle, message)

func _process_hello(outlet: DTPOutlet, handle: RefCounted, message: DTPHelloMessage):
	
	var peer: DTPPeer2
	handle.set_meta('uuid', message.uuid)
	if not peers.has_node(message.uuid):
		peer = DTPPeer2.new()
		peer.name = message.uuid
		peers.add_child(peer, true)
	else:
		peer = peers.get_node(message.uuid) as DTPPeer2
	
	peer.uuid = message.uuid
	peer.handle = handle
	peer.outlet = outlet
	peer.handle = handle
	
	connected.emit(peer)
		
func _process_message(outlet: DTPOutlet, handle: RefCounted, message: DTPMessage):
	if not handle.has_meta('uuid'): 
		push_warning("Received processable message from handle w/o UUID")
		return
	var uuid := handle.get_meta('uuid') as String
	var peer := peers.get_node(uuid) as DTPPeer2
	if not peer:
		push_error("Peer not found!")
		return
	peer.message.emit(message)
	
