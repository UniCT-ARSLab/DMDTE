class_name GameManager extends Node

var spawn_zones: Dictionary[int, SpawnerZone] = {}
var players: Dictionary[int, AlvikTank] = {}
var life_bars: Dictionary[int, LifeBar] = {}

var started: bool = false
func _ready():
	_ready_setup_lifebars()
	_ready_setup_spawn_zones()
	
func _ready_setup_spawn_zones():
	for zone in $"../Environment/SpawnZones".get_children():
		self.spawn_zones[zone.player_number] = zone
	
func _ready_setup_lifebars():
	var container: Node=  $"../UI/LifeContainer/HBoxContainer"
	for lb in container.get_children():
		if lb is LifeBar:
			life_bars[lb.player_number + 1] = lb

func add_player(player: AlvikTank):
	#print_debug("Collegato giocatore: %d" % player.peer_id)
	if player.peer_id < 1: return
	players[player.peer_id] = (player)
	life_bars[player.peer_id].player = player
	$MatchManager.on_player_added(player)
	

func _on_multiplayer_network_twin_spawned(twin):
	if twin is AlvikTank:
		add_player(twin)

@rpc("any_peer", "call_local", "reliable")
func reset():
	print_debug("reset")
	for player in players.values():
		player.reset()


func _on_dtp_network_on_digital_twin_spawn(instance: DigitalTwin) -> void:
	if not instance is AlvikTank: return
	
	instance.controllo_cannone.enabled = false
	instance.set_visibility(false)
	(instance as AlvikTank).on_dtp_ready.connect(
		func(dtpm: DTPPeer):
			var player_id: int = dtpm.peerId
			if not player_id in spawn_zones:
				push_warning("Unregistered player: %d" % player_id)
				return
			add_player(instance)
			var spawn_zone := spawn_zones[player_id]

			instance.set_home_position(spawn_zone.global_position)
			
			instance.ghost.spawn_pose = (Vector3(spawn_zone.global_position.x, spawn_zone.global_position.z, spawn_zone.global_rotation.y))
			instance.ghost.reset_pose_spawn()
			instance.set_visibility(true)
	)
	


func _on_start_game_pressed():
	pass

func _on_reset_player_pressed():
	pass
