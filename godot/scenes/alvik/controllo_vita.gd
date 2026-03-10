extends Node

@export var health: int = 3
@export var max_health: int = 3 
@export var invincibility_time: float = 3
@onready var invincibility_timer = $InvincibilityTimer
@onready var balloons = $Balloons
@onready var animated_flags = $"../Model/AnimatedFlags"
@onready var model = $"../Model"

signal damaged(player_id: int, health: int)

var invincible: bool = false
var flasha: bool = false
var timeTick: float = 0.0

func _ready():
	animated_flags.visible = false
	self.invincibility_timer.timeout.connect(_unmake_invincible)


func die():
	var tween = get_tree().create_tween()
	animated_flags.visible = true
	tween.tween_property(animated_flags, "position:y", animated_flags.position.y+7, 1)
	animated_flags.play("sventola", 1.5)
	get_parent().set_controllable(false)
	return

@rpc("authority", "call_local", "reliable")
func take_damage(damage: int):
	
	if invincible or health == 0: return
	
	var next_health = health - damage
	
	if next_health > 0 : _make_invincible()
	
	if health > 0:
		balloons.get_child(health - 1).detach()
	health = max(next_health, 0)

	damaged.emit(get_parent().peer_id, health)
	if health == 0:
		die()
	

#func take_damage(damage: int = 1):
#	_make_invincible()
	

func _process(delta):
	
	timeTick += delta
	if timeTick >= 1.0/20.0:
		timeTick = 0
		if flasha: 
			model.visible = !model.visible
		else:
			model.visible = true
	
func _make_invincible():
	self.invincible = true
	self.flasha = true
	self.invincibility_timer.start(invincibility_time)
	
func _unmake_invincible():
	self.invincible = false
	self.flasha = false
	model.visible = true
	pass

func reset():
	if health == 0:
		var tween = get_tree().create_tween()
		tween.tween_property(animated_flags, "position:y", animated_flags.position.y-7, 1)
		tween.tween_callback(func(): animated_flags.visible = false)
	for balloon in balloons.get_children():
		balloon.reset(model.global_transform)
	health = max_health
	
