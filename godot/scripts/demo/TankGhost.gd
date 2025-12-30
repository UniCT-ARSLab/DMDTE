extends DigitalGhost

@export var  battery: int = 0
var is_battery_charging: int = 0
var drive_speed: Vector2 = Vector2.ZERO


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"): 
		reset_pose()


var pose: Vector3:
	get:
		return Vector3(global_position.x, global_position.z, global_rotation.y)
	set(pose):
		self.global_position = pose.x * Vector3.FORWARD + pose.y * Vector3.LEFT
		self.global_rotation.y = pose.z

func drive(linear: float, angular: float) -> void:
	dtp_peer.call_method('drive', [linear, angular])

func reset_pose(x: float = 0, y: float= 0, theta: float= 0, force = 1):
	return dtp_peer.call_method('reset_pose', [-y, -x, theta, force])
