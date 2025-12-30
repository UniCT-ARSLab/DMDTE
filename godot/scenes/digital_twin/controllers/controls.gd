extends Node



func disableProcesses():
	for controller in get_children():
		controller.process_mode =  PROCESS_MODE_DISABLED
		
func enableProcesses():
	for controller in get_children():
		controller.process_mode =  PROCESS_MODE_INHERIT
