extends DigitalTwin
@onready var red = $Model/red
@onready var yellow = $Model/yellow
@onready var green = $Model/green

func _on_dtp_peer_on_update(_dtpm, update):
	for key in update:
		if key in self:
			var value : bool = (update[key] as int) > 0
			self[key].visible = value
			
	pass # Replace with function body.
