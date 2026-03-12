extends Node

@export var health: int:
	get: return _health
	set(value): set_health(value)

@export var max_health: int = 3 
@export var invincibility_time: float = 3
@onready var invincibility_timer = $InvincibilityTimer
@onready var flag: AnimationPlayer = $"../Model/Flag/AnimationPlayer"
@onready var model = $"../Model"
@export var invincible: bool = false

var balloons: Array[Balloon] = []
var is_dead: int:
	get: return health == 0

var _health: int
# var _invincible: int

signal died_signal(player_id: int)

var timeTick: float = 0.0

func _ready():
	for b in $Balloons.get_children():
		if b is Balloon: balloons.push_back(b)
	self.invincibility_timer.timeout.connect(_unmake_invincible)

	self.reset()


func die():
	flag_show()
	
	died_signal.emit(get_parent().peer_id)

func flag_show():
	flag.play("show")

func flag_reset():
	flag.play("reset")


func take_damage(damage: int):
	if not is_multiplayer_authority(): return
	var next_health = health - damage
	print("took damage, health is {0}, authority is {1}".format([next_health, get_multiplayer_authority()]))
	# do not take damage if invisible
	if invincible or is_dead: return
	
	
	
	health = next_health
	if next_health > 0: 
		_make_invincible()
	

		

func _physics_process(dt):
	_process_invincible_animation(dt)
	
	
func _process_invincible_animation(dt):
	var is_ingame := MatchManager.instance.in_game
	if is_ingame:
		timeTick += dt
		if timeTick >= 1.0/20.0:
			timeTick = 0
			if invincible: 
				model.visible = !model.visible
			else:
				model.visible = true
	else:
		model.visible = true

func _make_invincible():
	self.invincible = true
	self.invincibility_timer.start(invincibility_time)
	
func _unmake_invincible():
	self.invincible = false
	model.visible = true
	pass

func reset():
	if is_dead:
		flag_reset()
	health = max_health
	reset_ballons()


	
func reset_ballons():
	for balloon in balloons:
		balloon.reset(model.global_transform)

func set_health(next_health: int):
	var changed:= next_health != health
	self._health = max(next_health, 0)

	if changed:
		update_balloons(next_health)
		if is_dead:
			die()

func update_balloons(hp: int):
	for i in range(len(balloons)):
		var balloon:= balloons[i]
		if i + 1 > hp and balloon.is_attached:
			balloon.detach()
		elif i + 1 <= hp:
			balloon.reset(model.global_transform)
		
		
