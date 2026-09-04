extends AnimationPlayer

@export
var index2name:Dictionary[int,StringName]={}

func _on_curve_mover_3d_point_passed(point_index: int) -> void:
	if index2name.has(point_index):
		prints("playing:", index2name[point_index])
		play(index2name[point_index])
