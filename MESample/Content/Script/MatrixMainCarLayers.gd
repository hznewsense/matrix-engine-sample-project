extends Node3D

@export_flags_3d_render var layers: int = 1

func _ready() -> void:
	for visual: VisualInstance3D in find_children("*", "VisualInstance3D"):
		visual.layers = layers
