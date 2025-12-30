class_name PIDController
extends Resource
@export var kP: float = 1.0
@export var kI: float = 0.1
@export var kD: float = 0.0

@export_group("Input deadzone")
@export var apply_input_deadzone: bool = false
@export var input_deadzone: float = 0.0

@export_group("Output deadzone")
@export var apply_output_deadzone: bool = false
@export var output_deadzone: float = 0.0


@export_group("Windup")
@export var apply_windup: bool = false
@export var windup_low: float = 0.0
@export var windup_high: float = 0.0

@export_group("Saturation")
@export var apply_saturation: bool = false
@export var saturation_low: float = 0.0
@export var saturation_high: float = 0.0

@export_group("Step")
@export var apply_floor_step: bool = false
@export var floor_step: float = 0.0
@export var apply_ceil_step: bool = false
@export var ceil_step: float = 0.0

var prev_error: float = 0
var integral_sum: float = 0

func eval(dt: float, error: float) -> float:
	
	if apply_input_deadzone and abs(error) < input_deadzone: return 0
	
	
	
	var p: float = kP * error
	var i: float = integral_sum + (kI * error) * dt
	var d: float = kD * (error - prev_error) / dt
	
	integral_sum = i
	if apply_windup:
		integral_sum = clamp(integral_sum, windup_low, windup_high)
	
	var out: float = p + i + d
	
	if apply_floor_step:
		out = floor(out / floor_step) * floor_step
	if apply_ceil_step:
		out = ceil(out / ceil_step) * ceil_step

	if apply_output_deadzone and abs(error) < output_deadzone: return 0
	if apply_saturation: out = clampf(out, saturation_low, saturation_high)
	
	return out
	
	
	
