class_name RobotEurobot extends DigitalTwin

var pose : Vector3

func _on_dtp_peer_on_update(dtpm: DTPPeer, update: Dictionary) -> void:
	for key in update:
		if key in self:
			self[key] = update[key]
