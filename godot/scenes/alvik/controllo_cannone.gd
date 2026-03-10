extends Node
var bullet_scene = preload("res://scenes/bullet/bullet.tscn")

@export var reload_time: float = 3.0
@export var buffer_time: float = 2
@export var buffer_time_initial_scale: float = 0.5

@onready var bocca_cannone = $"../Model/BoccaCannone"
@onready var timer: Timer = $Timer
@onready var model = $"../Model"
@onready var controllo_cannone = $"."
@onready var cannon_fire: GPUParticles3D = $"../Model/BoccaCannone/CannonFire"

@onready var cannone_recharge_bar_sprite_3d = $"../Model/CannoneRechargeBarSprite3D"
@onready var recharge_progress_bar = $RechargeSubViewport/RechargeProgressBar

@onready var buffer_progress_bar = $BufferSubViewport/BufferProgressBar
@onready var buffer_bar_sprite_3d = $"../Model/BufferBarSprite3D"

var enabled: bool = false

var is_charging: bool = false
var can_fire: bool = false
var _time_buffer := 0.0
var _time_buffer_enabled := false

func set_can_fire(value: bool):
	can_fire = value
	is_charging = false
	_time_buffer_enabled = false
	_time_buffer = 0.0

func _process(delta):
	if not enabled: return
	if can_fire and _time_buffer_enabled:
		_time_buffer = clampf(_time_buffer + delta, 0, buffer_time)
		self.buffer_progress_bar.value = _time_buffer / buffer_time
	if not can_fire: _time_buffer = 0
	self.recharge_progress_bar.value = 1 -( timer.time_left / timer.wait_time)

func _input(event):
	
	var has_authority :=  get_multiplayer_authority() == multiplayer.multiplayer_peer.get_unique_id()
	if not has_authority or not DisplayServer.window_is_focused(): return
	
	# posso sparare e ho premuto il pulsante
	if can_fire and event.is_action_pressed("fire"):
		is_charging = true
		_time_buffer_enabled = true
		_time_buffer = 0.0
		buffer_bar_sprite_3d.visible = true
		
	# voglio sparare e rilascio il pulsante per sparare
	if is_charging and event.is_action_released("fire"):
		is_charging = false
		if not has_authority: return
		if has_authority and can_fire and enabled:
			can_fire = false
			
			cannone_recharge_bar_sprite_3d.visible = true
			self.buffer_progress_bar.value = 0.0
			
			buffer_bar_sprite_3d.visible = false

			var vscale := self.buffer_time_initial_scale + ( _time_buffer / buffer_time )
			spawn_capybullet.rpc(multiplayer.multiplayer_peer.get_unique_id(), vscale)
			timer.start(reload_time)
		pass

@rpc("any_peer", "call_local", "reliable")
func spawn_capybullet(id_auth: int, vscale: float = 0.5):
	var bullet: Node3D = bullet_scene.instantiate()
	#bullet.name = "Bullet"+str(id_auth + randi())
	bullet.setup(
		id_auth,
		get_parent(),
		bocca_cannone,
		vscale
	)
	cannon_fire.emitting = true
	#bullet.set_multiplayer_authority(id_auth)
	#bullet.tank_owner = get_parent().name
	#Globals.bullet_container.add_child(bullet)
	#cannon_fire.emitting = true
	#bullet.global_position = bocca_cannone.global_position
	#bullet.global_rotation.y = model.global_rotation.y
	#bullet.direction = -model.global_basis.z


func _on_timer_timeout():
	can_fire = true
	cannone_recharge_bar_sprite_3d.visible = false
	self.recharge_progress_bar.value = 0
