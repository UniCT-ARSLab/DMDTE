class_name MatchManager extends Node

static var instance : MatchManager

enum State {
	WaitingForPlayers,
	Countdown,
	InGame,
	Resetting
}
signal state_changed(state: State)

@onready var start_game: Button = $"../../StartGame"
@onready var players: Dictionary[int, AlvikTank] = get_parent().players

@onready var timer: Timer = $Timer

var my_player: AlvikTank
var num_players: int:
	get: return players.size()

var state: State = State.WaitingForPlayers
var num_defeated_players: int = 0
var in_game: bool:
	get: return state == State.InGame
var waiting_for_players: bool:
	get: return state == State.WaitingForPlayers
var transitioning: bool:
	get: return state == State.Countdown or state == State.Resetting

func _init():
	instance = self

func _input(event: InputEvent):
	if multiplayer.is_server() and event.is_action_pressed('match_reset'):
		notify_state_change.rpc(State.Resetting)


func _ready() -> void:
	state_changed.emit(self.state)
	start_game.visible = false


func on_player_added(player: AlvikTank):	
	if player.is_multiplayer_authority():
		
		my_player = player
		match state:
			State.InGame:
				player.set_controllable(true)
				player.set_invincible(false)
			State.WaitingForPlayers:
				player.set_can_shoot(false)
				player.set_controllable(true)
				player.set_invincible(true)
			State.Countdown|State.Resetting:
				player.set_controllable(false)
			
		
	player.controllo_vita.died_signal.connect(on_player_dead)
	show_start_button_if_necessary()

func show_start_button_if_necessary():
	var condition:= num_players > 1 and state == State.WaitingForPlayers
	start_game.visible = condition
	 

@rpc("authority", "call_local", "reliable")
func notify_state_change(next_state: State):
	
	self.state = next_state
	state_changed.emit(state)
	show_start_button_if_necessary()
	match state:
		State.WaitingForPlayers:
			state_changed_waiting_for_players()
		State.Countdown:
			state_changed_countdown()
		State.InGame:
			state_changed_ingame()
		State.Resetting:
			state_changed_resetting()
	
func state_changed_waiting_for_players():
	
	set_players_controllable(true)
	set_players_invincibility(true)
	set_players_can_shoot(false)
	
	
func state_changed_countdown():
	set_players_controllable(false)

func state_changed_ingame():
	set_players_invincibility(false)
	set_players_controllable(true)
	set_players_can_shoot(true)


func state_changed_resetting():
	set_players_controllable(false)
	set_players_invincibility(true)


	timer.start(3); await timer.timeout

	
	players_reset()
	
	timer.start(2); await timer.timeout
	
	if multiplayer.is_server():
		notify_state_change.rpc(State.WaitingForPlayers)

	set_players_invincibility(true)


@rpc("any_peer", "call_local", "reliable")
func player_request_begin_match():
	if not multiplayer.is_server(): return
	if state != State.WaitingForPlayers: return
	
	self.notify_state_change.rpc(State.Countdown)
	# start timer
	timer.start(3); await timer.timeout
	# switch in game
	self.notify_state_change.rpc(State.InGame)
	
func on_player_dead(player_id: int):
	if my_player.peer_id == player_id:
		my_player.set_controllable(false)
		my_player.set_can_shoot(false)
	
	if not multiplayer.is_server(): return

	num_defeated_players+=1
	if players.size() - num_defeated_players <= 1:
		num_defeated_players = 0
		print_debug("Match ended! ( sono autorità {0})".format([multiplayer.is_server()]))
		if multiplayer.is_server():
			notify_state_change.rpc(State.Resetting)
	
		
"""
@rpc("any_peer", "call_remote", "reliable")
func _on_player_dead(player_id: int):
	if multiplayer.is_server():
		print_debug("Player %d died!" % player_id)
	if not state == State.InGame: return


	num_defeated_players+=1
	if my_player.peer_id == player_id:
		my_player.set_controllable(false)
		my_player.set_can_shoot(false)

	if players.size() - num_defeated_players <= 1:
		num_defeated_players = 0
		print_debug("Match ended! ( sono autorità {0})".format([multiplayer.is_server()]))
		if multiplayer.is_server():
			notify_state_change.rpc(State.Resetting)
		
"""
func _on_start_game_pressed() -> void:
	self.player_request_begin_match.rpc()
	
func set_players_invincibility(value: bool):
	for p in self.players.values():
		(p as AlvikTank).set_invincible(value)
func set_players_can_shoot(value: bool):
	for p in self.players.values():
		(p as AlvikTank).set_can_shoot(value)
func set_players_controllable(value: bool):
	for p in self.players.values():
		(p as AlvikTank).set_controllable(value)
func players_reset():
	for p in self.players.values():
		(p as AlvikTank).reset()
