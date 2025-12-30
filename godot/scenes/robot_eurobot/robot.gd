extends CharacterBody3D

@onready var ghost: Node3D = $"../Ghost"
@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D

func _physics_process(delta: float) -> void:
	self.global_transform = ghost.global_transform
	var next_path_position: Vector3 = navigation_agent_3d.get_next_path_position()

func _on_timer_navigation_timeout() -> void:
	var targets = get_tree().get_nodes_in_group("Target")
	if targets.size() > 0 :
		navigation_agent_3d.set_target_position(targets[0].global_position)
