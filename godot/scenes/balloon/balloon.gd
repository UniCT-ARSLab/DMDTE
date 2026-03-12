class_name Balloon extends RigidBody3D


@export var max_height: float = 30
@export var joint: BalloonJoint
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_3d = $Sprite3D

var is_attached: bool:
	get: return joint.node_b != null


var initial_transform: Transform3D

var start_height: float = 0
func _ready():
	start_height = position.y
	initial_transform = global_transform



func _process(_delta):
	if position.y >= max_height:
		if not animation_player.is_playing():
			animation_player.play("disappear")
		
func detach():
	joint.node_b = NodePath()
	

func reset(origin: Transform3D):
	visible = true
	animation_player.stop()
	# sprite_3d.modulate = Color.WHITE
	self.global_transform = origin * initial_transform
	joint.node_b = get_path()
	if is_multiplayer_authority():
		sprite_3d.scale = Vector3.ONE * .8
		sprite_3d.modulate.a = clampf(.5,0.0,1.0)
	set_physics_process(true)

func _on_animation_player_animation_finished(_anim_name):
	set_physics_process(false)
	visible = false
