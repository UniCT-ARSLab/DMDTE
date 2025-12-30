class_name CommandLineArguments extends Node

var arguments: Dictionary = {}

func _init():
	_parse_arguments()
	
func _parse_arguments():
	var args:= OS.get_cmdline_user_args()
	for arg in args:
		_parse_argument(arg)
		
func _parse_argument(arg: String):
	var splitted := arg.split('=')
	var name_: String = splitted[0]
	if name_.begins_with('--'):
		name_ = name_.substr(2)
	var value = true
	if len(splitted) == 2:
		value = splitted[1]
	arguments[name_] = value
	
	
func get_bool(key: String, default: bool = false) -> bool:
	return true if key in arguments else default

func get_int(key: String, default = null ):
	return int(arguments[key]) if key in arguments else default

func get_float(key: String, default = null ):
	return float(arguments[key]) if key in arguments else default

func get_string(key: String, default = null ):
	return arguments[key] if key in arguments else default

func has_argument(key: String) -> bool:
	return key in arguments
