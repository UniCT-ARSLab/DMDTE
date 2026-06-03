@tool
extends EditorPlugin

const DTPSynchronizerEditor = preload('res://addons/dmdte/dtp/synchronizer/DTPSynchronizerEditor.gd')
var dtp_synchronizer_editor: DTPSynchronizerEditor

func _enable_plugin() -> void:
	# Add autoloads here.
	dtp_synchronizer_editor = DTPSynchronizerEditor.new()
	add_inspector_plugin(dtp_synchronizer_editor)
	
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	if dtp_synchronizer_editor:
		remove_inspector_plugin(dtp_synchronizer_editor)
		
	
	pass


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
