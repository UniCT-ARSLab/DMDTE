class_name DigitalTwin extends Node

@onready var dtp_peer: DTPPeer = $DTPPeer
# @onready var navigation_agent_3d = $Model/NavigationAgent3D
@onready var multiplayer_synchronizer = $MultiplayerSynchronizer
@onready var model = $Model
@onready var ghost = $Ghost
@onready var controls = $Controls


@export var identification := '';
@export var peer_id = -1
var isRemote = false


@export var multiplayer_peer_id: int = 1


func accept_peer(peer: ENetPacketPeer, id:int):
	dtp_peer.accept_peer(peer, id)
	peer_id = id

func _enter_tree():
	self.set_multiplayer_authority(self.multiplayer_peer_id)
	# multiplayer.multiplayer_peer.peer_disconnected.connect(_clean_dt)
		
func _ready():
	pass
func check_remote(arg: bool):
	isRemote = arg
	ghost.visible = isRemote
		

func _on_multiplayer_synchronizer_synchronized():
	return
	# if isRemote and multiplayer_peer_id == multiplayer.multiplayer_peer.get_unique_id():
	# 	queue_free()

func disableProcesses():
	dtp_peer.process_mode =  PROCESS_MODE_DISABLED
	ghost.visible = false
	if controls:
		controls.disableProcesses()

@rpc("authority", "call_local", "reliable")
func despawn_dt():
	disableProcesses()
	model.set_process(false)
	queue_free()
	
	#queue_free()


func set_visibility(visible:bool):
	model.visible = visible
	
