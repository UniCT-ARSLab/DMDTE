class_name DTPUDSOutlet extends DTPOutlet


@export var path: String
var server: UDSServer

func _enter_tree() -> void:
	var err :=  server.listen(path)
	if err:
		push_error(err)

func _exit_tree() -> void:
	pass
