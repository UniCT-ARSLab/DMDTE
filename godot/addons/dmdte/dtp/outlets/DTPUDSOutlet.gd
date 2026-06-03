class_name DTPUDSOutlet extends DTPStreanPeerBaseOutlet

@export var path: String

func begin():
	socket_server = UDSServer.new()
	if socket_server.is_listening(): return
	var err= socket_server.listen(self.path)
	if err:
		push_error(err);
		return err
