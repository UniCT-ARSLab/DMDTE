class_name AgentController extends Node
@onready var nav: NavigationAgent3D = $"../../Model/NavigationAgent3D"
@onready var model: CharacterBody3D = $"../../Model"

var _enabled:= false
var path: NavigationPathQueryResult3D
var enabled: bool:
	get(): return _enabled
	set(value):
		pass
		_enabled = value
var home_position: Vector3
func _process(delta: float) -> void:
	pass

func _ready() -> void:
	nav.velocity_computed.connect(_velocity_computed)
func return_home():
	nav.target_position = home_position
	await nav.path_changed
	path = nav.get_current_navigation_result()
		
	#model.drive(10, 0)
	
func _velocity_computed(safe_velocity: Vector3):
	return
	#if safe_velocity.length() == 0: return
	#print_debug("safe_velocity: {0}".format([safe_velocity]))
	#if not enabled: return
	#var theta:= model.rotation.y
	#var linear: float = safe_velocity.length() * sign(safe_velocity.dot(-model.basis.z))
	#var angular: = safe_velocity.normalized().dot(Vector3(sin(theta),0, cos(theta)))
	#model.drive(linear, angular)
