class_name AlvikTank extends DigitalTwin
signal on_dtp_ready(dtpm: DTPPeer)

@onready var controllo_cannone = $ControlloCannone
@onready var controllo_vita = $ControlloVita
@onready var phantom_camera_3d = $Model/PhantomCamera3D
@onready var manual_controller: ManualController = $Controls/ManualController
@onready var agent_controller = $Controls/AgentController




var curr_pose: Vector3
var past_pose: Vector3

var start_position: Vector3
var _material: StandardMaterial3D
var _color: Color:
	get: return _material.albedo_color
	set(color): _material.albedo_color = color

@onready var tank = $Model/Tank2/tank

func _on_dtp_peer_on_connect(dtpm: DTPPeer) -> void:
	if not self.isRemote:	
		phantom_camera_3d.set_priority(4)
		on_dtp_ready.emit(dtpm)
	
	set_color_using_player_id.rpc(dtpm.peerId)

#func _process(_delta):
#	var vec = phantom_camera_3d.get_third_person_rotation()
#	vec.y = model.global_rotation.y
#	phantom_camera_3d.set_third_person_rotation(vec)	
var mouse_sensitivity: float = 0.05

var min_yaw: float = 0
var max_yaw: float = 360

var min_pitch: float = -89.9
var max_pitch: float = 50

func _process(delta):
	pass	
		
@rpc("authority", "call_local", "reliable")
func set_color_using_player_id(player_id: int):
	var colors : = Globals.getPlayerColors()
	var key:='P%d' % player_id
	if key in colors:
		_color = colors[key]
	
func _ready():
	_duplicate_material()
	set_color_using_player_id(self.peer_id)
	
func _duplicate_material():
	_material = tank.get_active_material(0).duplicate()
	tank.set_surface_override_material(0, _material)

func set_invincible(value: bool):
	self.controllo_vita.invincible = value
	
func set_can_shoot(value: bool):
	controllo_cannone.set_can_fire(value)
	
func set_controllable(value: bool):
	self.controllo_cannone.enabled = value
	self.manual_controller.enabled = value
	set_can_shoot(false)
	self.model.drive(0.0,0.0)
	self.ghost.drive(0.0,0.0)
	
func set_home_position(home_position: Vector3):
	self.agent_controller.home_position = home_position
func return_to_home():
	self.agent_controller.enabled = true
	self.agent_controller.return_home()
	
func reset():
	controllo_vita.reset()
