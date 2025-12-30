extends Node3D

@export var initial_velocity: float = 100

@export var max_distance: float = 200
@export var gravity_scale: float = 1.0

@export_range(1, 60, 1.0) var max_time: float = 15

@onready var area_3d = $Area3D
@onready var timer = $Timer
@onready var multiplayer_synchronizer = $MultiplayerSynchronizer
var explosion_effect = preload("res://scenes/explosion/explosion.tscn")

var direction: Vector3 = Vector3.FORWARD
var tank_owner: String
var _space_traveled: float = 0
var _gravity = Vector3.DOWN * 9.81

var velocity: Vector3
func _ready():
	timer.start(max_time)
	

func _physics_process(delta):
	#if self.get_multiplayer_authority() != multiplayer.multiplayer_peer.get_unique_id(): return
	#print(str(multiplayer.multiplayer_peer.get_unique_id())+" non faccio nulla")
	velocity += _gravity * 2 * delta
	var displacement: Vector3 = (velocity) * delta
	
	global_position += displacement
	_space_traveled += displacement.length()
	
	look_at(global_position +  velocity.normalized())
	
	if _space_traveled > max_distance:
		cleanup()
	

func _on_area_3d_body_shape_entered(_body_rid, body, _body_shape_index, _local_shape_index):

	if body.get_parent().name != tank_owner:
		explode()
		if body.get_parent() is AlvikTank:
			(body.get_parent() as AlvikTank).controllo_vita.take_damage(1)
		cleanup()

func _on_timer_timeout():
	cleanup()


func cleanup():
	if is_inside_tree():
		set_physics_process(false)
		set_process(false)
		remove_child(multiplayer_synchronizer)
		_cleanup_impl()
	
@rpc("any_peer", "call_local", "reliable")
func _cleanup_impl():
	timer.stop()
	explode()
	#area_3d.monitoring = false
	#visible = false
	queue_free()
	
func setup(authority: int, owner_: Node, marker: Node3D, _velocity_scale: float = 1.0):
	self.set_multiplayer_authority(authority)
	self.tank_owner = owner_.name
	Globals.bullet_container.add_child(self)
	self.global_transform = marker.global_transform
	self.velocity = -global_basis.z * self.initial_velocity * _velocity_scale
	
func explode():
	var explosion : Explosion = explosion_effect.instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = self.global_position
	explosion.explode()
