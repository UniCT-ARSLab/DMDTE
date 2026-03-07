class_name DTPUDSOutlet extends DTPOutlet


@export var path: String
var server: UDSServer = UDSServer.new()

func begin():
	if server.is_listening(): return
	var err:= server.listen(self.path)
	if err:
		push_error(err);
		return err

func _process(delta: float) -> void:
	while server.is_listening():
		var stream:= server.take_connection()
		if not stream: break
		var kiddo = UDSDTPPeer.new()
		kiddo.stream = stream
		add_child(kiddo)

func _ready() -> void:
	if auto_start:
		self.begin()

func _enter_tree() -> void:
	pass

func _exit_tree() -> void:
	pass
