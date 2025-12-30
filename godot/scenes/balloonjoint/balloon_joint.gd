class_name BalloonJoint extends PinJoint3D


var _node_a: Node3D
var _node_b: Node3D

func _ready():
	_node_a = get_node(node_a)
	_node_b = get_node(node_b)
	_node_b.joint = self

func _process(_delta):
	if node_a and node_b:
		DebugDraw3D.draw_line(self.global_position, _node_b.global_position, Color.WHITE_SMOKE)

func attach(node: Node3D):
	self.node_b = node.get_path()
	self._node_b = node
