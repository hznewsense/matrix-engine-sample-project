extends Resource
class_name FollowConfig

@export var follow: NodePath
@export var speed: float = 5.0
@export_range(0.0, 1.0, 0.001)
var start_ratio: float = 0.0
@export var loop: bool = true
