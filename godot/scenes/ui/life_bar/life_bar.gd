class_name LifeBar extends Control



@export_enum("P1", "P2", "P3", "P4") var player_number : int
@onready var panel: Panel = $Panel
@onready var battery_level: ProgressBar = $Panel/VBoxContainer/HBoxContainer2/ProgressBar
@onready var player_name: Label = $Panel/VBoxContainer/HBoxContainer/Label
@onready var balloons: = ($Panel/VBoxContainer/HBoxContainer/HBoxContainer).get_children() as Array[Node]

var player: AlvikTank
var player_id



func _ready() -> void:
	
	player_id = player_number + 1
	player_name.text = "PLAYER %d"%player_id
	updateBatteryLevel(0)
	updateGraphics()
		

func updateGraphics():
	var theme = panel.get_theme_stylebox("panel").duplicate_deep()
	theme.set("bg_color", Globals.PLAYER_COLORS["P%d"%player_id])
	panel.add_theme_stylebox_override("panel", theme)
	
	pass


func updateBatteryLevel(newLevel:float):
	battery_level.value = newLevel
	#aggiornare_colore
func _process(_delta: float) -> void:
	if player:
		make_hidden(false)
		self.battery_level.value = player.ghost.battery
		for i in range(balloons.size()):
			var color = Color.WHITE if player.controllo_vita.health > i else Color(Color.WHITE, .5)
			(balloons[i] as TextureRect).modulate = color
	else:
		make_hidden(true)

func make_hidden(value: bool):
	self.modulate = Color.WHITE if not value else Color.TRANSPARENT 
