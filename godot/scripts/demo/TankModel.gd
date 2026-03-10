extends CharacterBody3D

@export var linearPid: PIDController
@export var angularPid: PIDController
@export var ghost: DigitalGhost

@export var linear_acceleration = 1.0
@export var angular_acceleration = 1.0
@export var max_speed: float = 10.0
@export var max_anguler_speed: float = PI / 2
@export var brake_scale: float = 5.0
@export var right_thread_anim: float = 0
@export var left_thread_anim: float = 0

@export var position_lerp_weight: float = 1.0
@export var rotation_slerp_weight: float = 1.0

var pose_buffer: Array[Vector3] = [ Vector3.ZERO, Vector3.ZERO ]

var linear: float = 0
var angular: float = 0
@onready var dtp_peer = $"../DTPPeer"
@onready var tank_model: MeshInstance3D = $Tank2/tank

var _angular_velocity: float = 0
var _linear_velocity: float:
	get:
		return self.velocity.length() * sign(self.velocity.dot(-basis.z))
	set(value):
		self.velocity = -basis.z * value

var _prev_drive_speed:= Vector2.ZERO

func _ready():
	tank_model.set_surface_override_material(1,tank_model.get_active_material(1).duplicate())
	tank_model.set_surface_override_material(2,tank_model.get_active_material(2).duplicate())
	pose_buffer[0] =  _extract_pose()
	pose_buffer[0] = pose_buffer[1]

func _input(event: InputEvent) -> void:
	if event.is_action("reset"): 
		self.position = Vector3.ZERO
		self.rotation = Vector3.ZERO

func drive(linear_: float, angular_: float):
	self.linear = linear_
	self.angular = angular_

func _process(delta):
	_physics_update_tank_threads(delta)
	pose_buffer[1] = pose_buffer[0]
	pose_buffer[0] = _extract_pose()

func _physics_process(dt: float) -> void:
	_physics_process_drive(dt)


func _physics_process_drive(dt: float):
	var ang_vel: float = _angular_velocity
	var lin_vel: float = _linear_velocity
	
	var next_ang_vel =  ang_vel +  angularPid.eval(dt, angular - ang_vel)
	var next_lin_vel = lin_vel +  linearPid.eval(dt, linear - lin_vel)

	if abs(next_ang_vel) < .1: next_ang_vel = 0
	if abs(next_lin_vel) < .1: next_lin_vel = 0
		
	self._angular_velocity = next_ang_vel 
	self._linear_velocity = next_lin_vel
	
	rotate_y(self._angular_velocity * dt)
	
	var kcd := move_and_collide(velocity * dt, true, safe_margin, false)
	if kcd != null and kcd.get_collision_count() > 0:
		
		#var direction:= kcd.get_position().direction_to(position)
		var angle:= kcd.get_angle()
		if abs(sin(angle)) > .5:
			velocity = Vector3.ZERO
			
	if velocity != Vector3.ZERO:
		move_and_slide()

	if ghost and dtp_peer.is_active:
		var linear_velocity: float = _linear_velocity if abs(linear) > 0.0 else 0.0
		var angular_velocity: float = _angular_velocity if abs(angular) > 0.0 else 0.0
		
	

			
		ghost.drive(linear_velocity, angular_velocity)
		if not is_on_wall():
			_physics_process_drive_lerp2ghost(dt)
	
	

func _physics_process_drive_lerp2ghost(dt: float):
	position = position.lerp(ghost.position,position_lerp_weight * dt)
	rotation.y = lerp_angle(rotation.y, ghost.rotation.y, rotation_slerp_weight * dt)

func _extract_pose():
	return Vector3(self.global_position.x, self.global_position.z, self.global_rotation.y)
	

func _physics_update_tank_threads(dt: float):
	var dpose: Vector3 = pose_buffer[0] - pose_buffer[1]
	var theta := pose_buffer[0].z
	var dtheta := dpose.z
	var dspace := Vector2(dpose.x, dpose.y)
	var vel := dspace.length() * dspace.dot(Vector2(sin(theta), cos(theta)))
	
	(tank_model.get_surface_override_material(1) as StandardMaterial3D).uv1_offset += Vector3.UP * vel + Vector3.UP* (dtheta )
	(tank_model.get_surface_override_material(2) as StandardMaterial3D).uv1_offset += Vector3.UP * vel - Vector3.UP* (dtheta )
	
	return
