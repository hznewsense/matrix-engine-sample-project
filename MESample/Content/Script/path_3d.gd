#extends Path3D
#
#@onready var follow: PathFollow3D = $PathFollow3D
#@export var speed: float = 20.0
#
#func _process(delta: float) -> void:
	## 按比例推进，自动 0~1 循环
	#var total := self.curve.get_baked_length()
	#if total > 0.0:
		#follow.progress_ratio = fmod(follow.progress_ratio + (speed * delta) / total, 1.0)


extends Path3D

@export var configs: Array[FollowConfig] = []   # 配置多个物体
@export var use_progress_ratio: bool = true     # 推荐用比例推进，天然循环更顺滑

func _ready() -> void:
	# 初始化每个跟随者
	for cfg in configs:
		var f = get_node_or_null(cfg.follow)
		if f is PathFollow3D:
			f.loop = cfg.loop
			if use_progress_ratio:
				f.progress_ratio = cfg.start_ratio
			elif curve:
				f.progress = curve.get_baked_length() * cfg.start_ratio

func _physics_process(delta: float) -> void:
	if not curve:
		return

	var total_len := curve.get_baked_length()
	if total_len <= 0.0:
		return

	for cfg in configs:
		var f = get_node_or_null(cfg.follow)
		if not (f is PathFollow3D):
			continue

		if use_progress_ratio:
			var step := (cfg.speed * delta) / total_len
			if cfg.loop:
				f.progress_ratio = fmod(f.progress_ratio + step, 1.0)
			else:
				f.progress_ratio = clamp(f.progress_ratio + step, 0.0, 1.0)
		else:
			# 使用绝对进度（米），需要自己处理循环/夹住
			f.progress += cfg.speed * delta
			if cfg.loop:
				f.progress = fmod(f.progress, total_len)
			else:
				f.progress = clamp(f.progress, 0.0, total_len)
