extends Camera3D
class_name PanCamera

@export var focusTarget: Node3D
@export var followSpeed: float = 1.0
@export var distanceFromGround: float = 60
@export var distanceFromGroundBounds: Vector2 = Vector2(30, 90)
@export var panBounds: AABB = AABB(Vector3.ZERO, Vector3(1.0,1.0,1.0))
@export var zoomSpeed = 1.0
@export var waypoint: Node3D

@onready var raycaster = $RayCast3D

var target_vec: Vector3

var mouse_positions: Array[Vector2] = [ Vector2.ZERO, Vector2.ZERO ]
# Called when the node enters the scene tree for the first time.
func _ready():
	if waypoint: waypoint.visible = false
	if focusTarget != null:
		target_vec = focusTarget.global_position
	
	global_position = compute_target_position();
	pass # Replace with function body.

func _input(event: InputEvent) -> void:
	var low = distanceFromGroundBounds.x
	var high = distanceFromGroundBounds.y
	if event.is_action('zoom_in'):
		distanceFromGround = clampf(distanceFromGround - 1 * zoomSpeed, low, high)
	if event.is_action('zoom_out'):
		distanceFromGround = clampf(distanceFromGround + 1 * zoomSpeed, low, high)
	
	if event.is_action('left_click'):
		place_waypoint()
	if event.is_action("focus_target") and focusTarget != null:
		target_vec = focusTarget.global_position
		global_position = compute_target_position()
		# actionTimer.start()
	
func place_waypoint():
	return
	# var mousePosition = get_viewport().get_mouse_position()
	# raycaster.target_position = project_local_ray_normal(mousePosition) * distanceFromGround * 2
	# raycaster.force_raycast_update()
	# if raycaster.is_colliding():
	# 	var point: Vector3= raycaster.get_collision_point()
	# 	waypoint.visible = true
	# 	waypoint.position = point
	# 	waypoint.position.y = 0
	# 	#waypoint.rotation.y = randf_range(-PI, PI)
	# 	focusTarget.update_target_location(waypoint.position)
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pan_target(delta)
	self.global_position = lerp(self.global_position, compute_target_position(),  delta * followSpeed)
	
func pan_target(delta: float):
	if not DisplayServer.window_is_focused(): return
	pan_target_mouse(delta)
	var pan: Vector2 = Vector2.ZERO
	pan += Input.get_axis("pan_left", "pan_right") * Vector2.RIGHT
	pan += Input.get_axis("pan_up", "pan_down") * Vector2.DOWN
	if pan.length() > .25:
		var next = target_vec + Vector3(pan.x, 0, pan.y) * delta * (followSpeed**2)  
		target_vec = next
func pan_target_mouse(delta: float):
	mouse_positions[1] = mouse_positions[0]
	mouse_positions[0] = get_viewport().get_mouse_position()
	if Input.is_action_pressed("pan"):
		var diff = mouse_positions[1] - mouse_positions[0]
		var next = target_vec + Vector3(diff.x, 0, diff.y) * delta * followSpeed
		target_vec = next
	
		# if self.panBounds.has_point(next):
	
func compute_target_position():
	return target_vec + self.global_basis.z * distanceFromGround
