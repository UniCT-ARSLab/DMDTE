class_name DTPPeer2 extends Node



var name_: String
var uuid: String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _enter_tree():
	connected()

func _exit_tree():
	disconnected()


func connected():
	var parent:= (get_parent() as DTPOutlet)
	parent.peer_connected.emit(self)

func disconnected():
	var parent:= (get_parent() as DTPOutlet)
	parent.peer_disconnected.emit(self)
