# An outlet is a server that manages DTP links via a transport protocol
class_name DTPOutlet extends Node

var server: DTPServer
@export var auto_start: bool = true


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var p = get_parent()
	if p is DTPServer:
		server = p
	else:
		push_error("DTPOutlet parent is not a DTPServer")
		return

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_cleanup()

func _cleanup():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func process_message(handle: RefCounted, message: DTPMessage):
	server.process_message(self, handle, message)

func dispatch(peer: DTPPeer2, message: DTPMessage) -> Error:
	return Error.FAILED
