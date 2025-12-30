extends Node3D

@onready var bullets = $Bullets

func _ready():
	Globals.bullet_container = bullets
