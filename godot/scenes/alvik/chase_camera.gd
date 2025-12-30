@tool
extends PhantomCamera3D
@export var weight: float = 1.0
# trasformazione iniziale ( locale alla sottoscena )
@onready var initial_transform: Transform3D = self.global_transform
@onready var parent: Node3D = self.get_parent()
func _process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	# calcolo la trasformazione globale
	var target:= parent.global_transform * (initial_transform)
	# interpolo la globale della camera con quanto calcolato prima
	self.global_transform =  self.global_transform.interpolate_with(target, delta * weight)
	
