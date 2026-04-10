class_name ManualController extends Node


enum ControllerMode {
	Polar,
	Steering
}

@export var model: Node3D
@onready var alvik: AlvikTank = $"../.."

@export var speed: float = 10
@export var angularSpeed: float = PI / 2
@export var mode: ControllerMode = ControllerMode.Polar
@export var drawDirectionArrow: bool = false

var direction:= Vector2.ZERO
var device: int = -1

const vertical_axis:= 1
const horizontal_axis:= 0
const buttons:= {
	0: 'fire',
	1: 'fire',
	6: 'start',
	11: 'up',
	12: 'down',
	13: 'left',
	14: 'right'
}
@export var enabled = true

func _input(event: InputEvent):
	if event.device != device: return
	if event is InputEventJoypadMotion:
		var value:= event.axis_value as float
		value = value if abs(value) > 0.5 else 0.0
		match event.axis:
			vertical_axis:
				direction.y = -value
			horizontal_axis:
				direction.x = -value
			

	if event is InputEventJoypadButton:
		var index:= event.button_index as int
		var pressed:= int(event.pressed)
		if not index in buttons: return
		match buttons[index]:
			'fire':
				var evt = InputEventAction.new()
				evt.action = "fire"
				evt.pressed = event.pressed
				Input.parse_input_event(evt)
			'start':
				var evt = InputEventAction.new()
				evt.action = "start"
				evt.pressed = event.pressed
				Input.parse_input_event(evt)			
			'up':
				direction.y = 1 * pressed
			'down':
				direction.y = -1 * pressed
			'left':
				direction.x = 1 * pressed
			'right':
				direction.x = -1 * pressed



		

func _physics_process(_delta: float) -> void:
	if not enabled : return
	
	#if not DisplayServer.window_is_focused(): return
	
	# var gas: float = Input.get_axis("gas_backward", "gas_forward")
	match mode:
		ControllerMode.Polar:
			pass
			#var direction: Vector3 = Vector3.ZERO
			#direction += Input.get_axis("down","up") * Vector3.FORWARD
			#direction += Input.get_axis("left","right") * Vector3.RIGHT
			#direction = direction.normalized()
			#_polar_controller(direction, gas)
			
		ControllerMode.Steering:
			_steering_controller(direction.x, direction.y)
			#var left: float =  -Input.get_axis("left","right")
			#if gas < 0:
			#	left = -left
			#_steering_controller(left, gas)
	#direction *= 0.0
	
func _polar_controller(dir: Vector3, gas: float):
	var fwd = -model.basis.z
	var thetaFwd = atan2(fwd.z, fwd.x)
	var thetaDir = atan2(dir.z, dir.x)
	if gas < 0:
		thetaFwd -= PI
	
	var thetaErr = angle_difference(thetaFwd, thetaDir)
	if dir.length() == 0: thetaErr = 0
	
	model.drive(
		gas * speed,
		clampf(-thetaErr, -angularSpeed, angularSpeed)
	)

func _steering_controller(right: float, gas: float):
	model.drive(
		gas * speed,
		right * angularSpeed
	)

func _draw_debug_arrow():
	var _pos:= model.position


func _ready():
	self.device = alvik.peer_id - 1
