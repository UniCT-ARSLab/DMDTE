extends EditorInspectorPlugin

func _can_handle(object: Object) -> bool:
	return object is DTPSynchronizer

func _parse_begin(object):
	var btn:= Button.new()
	btn.text = "clicca puppo"
	btn.pressed.connect(func():
		EditorInterface.popup_node_selector(func(p: NodePath):
			var node:= EditorInterface.get_edited_scene_root().get_node(p)
			EditorInterface.popup_property_selector(node, func(prop):
				print(prop)
			, [TYPE_INT])
		)
		pass
	)
	
	add_custom_control(btn)
	
	pass

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	if name == 'config':
		var inspecetor = preload('res://addons/dmdte/dtp/synchronizer/synchronizer/synchronizer_editor.tscn').instantiate()
		add_property_editor('skibidi', inspecetor)
		return true
	return false
	
