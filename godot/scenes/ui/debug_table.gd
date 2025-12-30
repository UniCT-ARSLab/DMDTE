extends Control
@onready var window := $Window
@onready var container := $Window/VBoxContainer
@export var template: PackedScene


func _ready() -> void:
	pass

func _process(delta):
	return
	#window.title = "Table [%d]" % [multiplayer.multiplayer_peer.get_unique_id()]	
		

		

func debug(key: String, value: Variant):
	var child: RecordTemplate
	if not container.has_node(key):
		child = template.instantiate()
		child.name = key
		container.add_child(child)
	else:
		child = container.get_node(key)
	child.set_data(key, '{0}'.format([value]))

func toggle_debug_window():
	window.visible = !window.visible
	pass # Replace with function body.
