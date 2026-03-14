class_name ManualController extends Node

signal fire()

enum ControllerMode {
	Polar,
	Steering
}

@export var model: Node3D

@export var speed: float = 10
@export var angularSpeed: float = PI / 2
@export var mode: ControllerMode = ControllerMode.Polar
@export var drawDirectionArrow: bool = false

var direction:= Vector3.ZERO

@export var enabled = true

func _input(event: InputEvent):
	if event is InputEventJoypadMotion:
		
		print("Device: {0}, axis: {1}, axis_value: {2}".format([event.device, event.axis, event.axis_value]))
		
	

func _physics_process(_delta: float) -> void:
	if not enabled : return
	
	#if not DisplayServer.window_is_focused(): return
	
	var gas: float = Input.get_axis("gas_backward", "gas_forward")
	match mode:
		ControllerMode.Polar:
			var direction: Vector3 = Vector3.ZERO
			direction += Input.get_axis("down","up") * Vector3.FORWARD
			direction += Input.get_axis("left","right") * Vector3.RIGHT
			direction = direction.normalized()
			_polar_controller(direction, gas)
			
		ControllerMode.Steering:
			var left: float =  -Input.get_axis("left","right")
			if gas < 0:
				left = -left
			_steering_controller(left, gas)
	
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
