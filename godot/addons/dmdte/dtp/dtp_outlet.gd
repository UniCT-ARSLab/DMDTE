# An outlet is a server that manages DTP links via a transport protocol
class_name DTPOutlet extends Node


@export var auto_start: bool = true
signal peer_connected(peer: DTPPeer2)
signal peer_disconnected(peer: DTPPeer2)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
