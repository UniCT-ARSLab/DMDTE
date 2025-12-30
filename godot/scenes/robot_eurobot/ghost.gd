extends DigitalGhost



var pose: Vector3:
	get:
		return Vector3(global_position.x, global_position.z, global_rotation.y)
	set(pose):
		self.global_position = pose.x * Vector3.FORWARD + pose.y * Vector3.LEFT
		self.global_rotation.y = pose.z
