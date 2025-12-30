@tool
class_name SpawnerZone extends Node3D

@export_enum("P_INVALID", "P1", "P2", "P3", "P4") var player_number : int

@onready var mesh: MeshInstance3D = $Mesh
@onready var label_3d: Label3D = $Label3D

var player_id
var colors:Dictionary[String, Color]
var _updated:bool = false

func _ready() -> void:
	
	player_id = player_number + 1
	mesh.set_surface_override_material(0, mesh.get_surface_override_material(0).duplicate())
	if Engine.is_editor_hint():
		var glob = preload("res://autoloads/Globals.gd").new()
		colors = glob.getPlayerColors()
	else:
		colors = Globals.getPlayerColors()
		updateGraphics()

func _process(_delta: float) -> void:
	
	if Engine.is_editor_hint() and self.is_node_ready() and not _updated:
		_updated = true
		updateGraphics()

func updateGraphics():
	label_3d.text = "P"+str(player_number)
	label_3d.modulate = colors["P"+str(player_number)]
	mesh.get_surface_override_material(0).albedo_color = colors["P%d" % player_number]
	
