extends CameraController3D

## 相机模式枚举
## 0: Launcher - 启动器模式
## 1: VehicleSettings - 车辆设置模式
## 2: Navigate - 导航模式
## 3: Interior - 内饰模式
## 4: Application - 应用程序模式
## 5: Charging - 充电模式
## 6: Music - 音乐模式
enum CameraMode {
	LAUNCHER = 0,
	VEHICLE_SETTINGS = 1,
	NAVIGATE = 2,
	INTERIOR = 3,
	APPLICATION = 4,
	CHARGING = 5,
	MUSIC = 6
}

@export var matrix_main_car: Node3D

## 档位控制器引用（用于SR模式自动切D档）
@export var gear_controller: GearController

## 主车碰撞形状数组（7个CollisionShape3D）
@export var main_car_collision_shapes: Array[CollisionShape3D]

## 模式UI管理器引用
@export var mode_ui_manager: ModeUIManager

## 车漆材质引用（SR模式时降低高光强度）
@export var car_paint_material: Material

## 四门三盖管理器引用
@export var door_lid_manager: DoorLidManager

## 四门三盖控制器引用（用于同步交互许可）
@export var door_controller: DoorController


## 原点Transform
var camera_origin_transform: Transform3D
## 跟随偏移Transform
var camera_offset_transform: Transform3D
## 是否在SR状态（镜头随车）
var is_in_sr_state: bool = false
## 当前模式索引（-1表示未设置）
var current_mode_index: int = -1
## 是否正在执行复位动画（防止复位过程被打断）
var is_resetting: bool = false
## 当前正在切换的目标模式索引（-1表示没有进行中的切换）
var switching_to_index: int = -1
## 操作序列号（用于检测是否被新操作打断）
var operation_serial: int = 0

## cull_mask 配置
const CULL_MASK_LAUNCHER: int = 4293918757
const CULL_MASK_VEHICLE_SETTINGS: int = 4293918757
const CULL_MASK_NAVIGATE: int = 4293918802
const CULL_MASK_INTERIOR: int = 4293918753
const CULL_MASK_APPLICATION: int = 4293918757
const CULL_MASK_CHARGING: int = 4293918757
const CULL_MASK_MUSIC: int = 4293918757
## cull_mask 延迟切换时间（秒）
const CULL_MASK_DELAY: float = 0.4
## 模式切换/复位的锁定时间（秒），需 >= CULL_MASK_DELAY
const MODE_SWITCH_LOCK_TIME: float = 1.0

## 模式配置字典：mode_index -> {camera_index, cull_mask, is_sr_mode, use_camera_origin}
## camera_index: 相机数据表索引（-1表示无相机数据，纯UI模式）
## is_sr_mode: 是否使用SR模式（镜头跟随车辆）
## use_camera_origin: 切换后是否回到原点位置
var _mode_configs: Dictionary = {}

func _init_mode_configs() -> void:
	_mode_configs = {
		CameraMode.LAUNCHER: {
			"camera_index": 0,
			"cull_mask": CULL_MASK_LAUNCHER,
			"is_sr_mode": false,
			"use_camera_origin": true
		},
		CameraMode.VEHICLE_SETTINGS: {
			"camera_index": 1,
			"cull_mask": CULL_MASK_VEHICLE_SETTINGS,
			"is_sr_mode": false,
			"use_camera_origin": true
		},
		CameraMode.NAVIGATE: {
			"camera_index": 2,
			"cull_mask": CULL_MASK_NAVIGATE,
			"is_sr_mode": true,
			"use_camera_origin": false
		},
		CameraMode.INTERIOR: {
			"camera_index": 3,
			"cull_mask": CULL_MASK_INTERIOR,
			"is_sr_mode": false,
			"use_camera_origin": true
		},
		CameraMode.APPLICATION: {
			"camera_index": -1,
			"cull_mask": CULL_MASK_APPLICATION,
			"is_sr_mode": false,
			"use_camera_origin": true
		},
		CameraMode.CHARGING: {
			"camera_index": 4,
			"cull_mask": CULL_MASK_CHARGING,
			"is_sr_mode": false,
			"use_camera_origin": true
		},
		CameraMode.MUSIC: {
			"camera_index": -1,
			"cull_mask": CULL_MASK_MUSIC,
			"is_sr_mode": false,
			"use_camera_origin": true
		}
	}

func _get_mode_config(mode_index: int) -> Dictionary:
	return _mode_configs.get(mode_index, {})

func _get_mode_cull_mask(mode_index: int) -> int:
	var config = _get_mode_config(mode_index)
	return config.get("cull_mask", CULL_MASK_LAUNCHER)

func _get_mode_is_sr_mode(mode_index: int) -> bool:
	var config = _get_mode_config(mode_index)
	return config.get("is_sr_mode", false)

func _get_mode_use_camera_origin(mode_index: int) -> bool:
	var config = _get_mode_config(mode_index)
	return config.get("use_camera_origin", true)

## 获取模式的相机数据表索引
func _get_mode_camera_index(mode_index: int) -> int:
	var config = _get_mode_config(mode_index)
	return config.get("camera_index", -1)

## 判断是否为纯UI模式（无相机参数，只有UI）
func _is_ui_only_mode(mode_index: int) -> bool:
	return _get_mode_camera_index(mode_index) == -1



func _ready() -> void:
	# 设置物理帧优先级，确保在 VehicleDataController 之后执行
	process_priority = 20

	# 初始化模式配置
	_init_mode_configs()

	_save_origin_transform()
	_calculate_camera_offset()

	# 连接ModeUIManager的信号
	if mode_ui_manager:
		mode_ui_manager.mode_switch_requested.connect(_on_mode_switch_requested)
	# 延迟初始化Launcher模式，确保所有节点的@export属性已解析完毕
	_init_launcher_mode.call_deferred()


## 延迟初始化Launcher模式
func _init_launcher_mode() -> void:
	current_mode_index = CameraMode.LAUNCHER
	mode_ui_manager.current_mode_index = current_mode_index
	mode_ui_manager.update_ui_visibility(CameraMode.LAUNCHER)
	mode_ui_manager.update_mask_texture(CameraMode.LAUNCHER)


func _on_mode_switch_requested(mode_index: int) -> void:
	switch_to_mode(mode_index)


func _save_origin_transform() -> void:
	camera_origin_transform = global_transform


func _calculate_camera_offset() -> void:
	if not matrix_main_car:
		return

	var camera_inv = matrix_main_car.global_transform.affine_inverse()
	camera_offset_transform = camera_inv * global_transform


func _process(_delta: float) -> void:
	if is_in_sr_state:
		_apply_camera_follow()


func _apply_camera_follow() -> void:
	if not matrix_main_car:
		return

	var car_xform = matrix_main_car.global_transform
	# Strip scale to prevent camera from inheriting car scale
	var car_basis = car_xform.basis.orthonormalized()
	car_xform = Transform3D(car_basis, car_xform.origin)
	var target_transform = car_xform * camera_offset_transform
	global_transform = target_transform



## 同步 C++ elastic 值到当前 spring_arm 状态
## 调用 switch_by_index 捕获当前 spring_arm 状态为 source
## 然后 set_play_percentage(0) 让 elastic 值 = source（即当前值）
## 注意：这会启动一个过渡动画（is_switching_view = true），
## 但拖拽事件会立即取消该过渡（_input_drag 中 is_switching_view = false）
func _sync_elastic_to_current() -> void:
	var cam = _get_camera()
	var saved_mask = cam.cull_mask if cam else 0
	switch_by_index(_current_camera_table_index)
	set_play_percentage(0.0)
	if cam and saved_mask != 0:
		cam.cull_mask = saved_mask

func _apply_camera_origin() -> void:
	global_transform = camera_origin_transform


func jump_camera_to_car() -> void:
	_apply_camera_follow()


func jump_camera_to_origin() -> void:
	_apply_camera_origin()


func set_view_mode(is_sr: bool) -> void:
	is_in_sr_state = is_sr
	# SR模式时降低车漆高光强度，非SR时恢复
	if car_paint_material and car_paint_material is ShaderMaterial:
		var intensity: float = 0.0 if is_sr else 1.2
		car_paint_material.set_shader_parameter("ExtraSpecularIntensity", intensity)


## 通用模式切换函数
## 纯UI模式（APPLICATION/MUSIC）特殊处理：
## - 切到纯UI模式：无相机操作，立即切换UI
## - 从纯UI模式切到其他模式：有相机操作，立即切换（不等CULL_MASK_DELAY）
func switch_to_mode(mode_index: int) -> void:
	var my_serial: int = operation_serial + 1
	operation_serial = my_serial
	switching_to_index = mode_index

	if is_resetting and switching_to_index != current_mode_index:
		is_resetting = false
	elif is_resetting and switching_to_index == current_mode_index:
		return

	is_resetting = true

	# 同步当前模式到ModeUIManager
	mode_ui_manager.current_mode_index = current_mode_index

	# 同一模式复位
	if current_mode_index == mode_index:
		if _is_ui_only_mode(mode_index):
			# 纯UI模式复位：只刷新UI，无相机操作，立即完成
			mode_ui_manager.update_ui_visibility(mode_index)
			mode_ui_manager.update_mask_texture(mode_index)
			is_resetting = false
			switching_to_index = -1
		else:
			# 常规模式复位：复位相机动画
			var cam_idx = _get_mode_camera_index(mode_index)
			_kill_camera_adjust_tween()
			switch_by_index(cam_idx)
			_current_camera_table_index = cam_idx
			_cache_camera_limits()
			await get_tree().create_timer(MODE_SWITCH_LOCK_TIME).timeout
			if my_serial == operation_serial:
				is_resetting = false
				switching_to_index = -1
		return

	var target_is_ui_only = _is_ui_only_mode(mode_index)
	var source_is_ui_only = _is_ui_only_mode(current_mode_index)
	var previous_mode_index := current_mode_index

	current_mode_index = mode_index
	# 同步当前模式到ModeUIManager
	mode_ui_manager.current_mode_index = current_mode_index

	# 特殊处理：切到SR模式时，如果档位不是D档就自动切到D档
	if _get_mode_is_sr_mode(mode_index) and gear_controller:
		if gear_controller.current_gear != GearController.Gear.D:
			gear_controller.set_gear(GearController.Gear.D)

	if target_is_ui_only:
		# 切到纯UI模式（Application/Music）：无相机操作，立即切换UI
		# 注意：Application/Music与四门三盖隔离，不触发任何门盖操作
		mode_ui_manager.update_ui_visibility(mode_index)
		mode_ui_manager.update_mask_texture(mode_index)
		_update_main_car_collision_disabled()
		is_resetting = false
		switching_to_index = -1
	elif source_is_ui_only:
		# 从纯UI模式切到常规模式：有相机操作，立即切换（不等CULL_MASK_DELAY）
		var cam_idx = _get_mode_camera_index(mode_index)
		_kill_camera_adjust_tween()
		switch_by_index(cam_idx)
		_current_camera_table_index = cam_idx
		_cache_camera_limits()

		# 立即设置相机位置和SR模式
		var use_origin = _get_mode_use_camera_origin(mode_index)
		var is_sr = _get_mode_is_sr_mode(mode_index)
		if use_origin:
			jump_camera_to_origin()
		else:
			jump_camera_to_car()
		set_view_mode(is_sr)

		_set_camera_cull_mask(_get_mode_cull_mask(mode_index))
		mode_ui_manager.update_mask_texture(mode_index)
		mode_ui_manager.update_ui_visibility(mode_index)
		_update_main_car_collision_disabled()
		# SR(Navigate)↔Interior切换的特殊处理
		if previous_mode_index == CameraMode.NAVIGATE and mode_index == CameraMode.INTERIOR:
			# SR→Interior：假关（无动画，瞬间设为关闭状态）
			door_lid_manager.apply_close_instant()
		elif previous_mode_index == CameraMode.INTERIOR and mode_index == CameraMode.NAVIGATE:
			# Interior→SR：跳过，无需任何门盖操作（SR车始终关闭）
			pass
		elif mode_index == CameraMode.INTERIOR:
			door_lid_manager.apply_close()
		elif door_lid_manager.is_state_saved():
			door_lid_manager.restore()

		await get_tree().create_timer(MODE_SWITCH_LOCK_TIME).timeout
		if my_serial == operation_serial:
			is_resetting = false
			switching_to_index = -1
	else:
		# 常规模式间切换：保留原始行为（带CULL_MASK_DELAY）
		var old_cull_mask: int = _get_camera_cull_mask()
		var cam_idx = _get_mode_camera_index(mode_index)
		_kill_camera_adjust_tween()
		switch_by_index(cam_idx)
		_current_camera_table_index = cam_idx
		_cache_camera_limits()
		_set_camera_cull_mask(old_cull_mask)

		await get_tree().create_timer(CULL_MASK_DELAY).timeout

		# 根据模式配置设置相机位置和SR模式
		var use_origin = _get_mode_use_camera_origin(mode_index)
		var is_sr = _get_mode_is_sr_mode(mode_index)

		if use_origin:
			jump_camera_to_origin()
		else:
			jump_camera_to_car()

		set_view_mode(is_sr)
		_set_camera_cull_mask(_get_mode_cull_mask(mode_index))
		mode_ui_manager.update_mask_texture(mode_index)

		# 更新UI显示
		mode_ui_manager.update_ui_visibility(mode_index)

		# 更新主车碰撞形状禁用状态
		_update_main_car_collision_disabled()

		# SR(Navigate)↔Interior切换的特殊处理
		if previous_mode_index == CameraMode.NAVIGATE and mode_index == CameraMode.INTERIOR:
			# SR→Interior：假关（无动画，瞬间设为关闭状态）
			door_lid_manager.apply_close_instant()
		elif previous_mode_index == CameraMode.INTERIOR and mode_index == CameraMode.NAVIGATE:
			# Interior→SR：跳过，无需任何门盖操作（SR车始终关闭）
			pass
		elif mode_index == CameraMode.INTERIOR:
			door_lid_manager.apply_close()
		elif door_lid_manager.is_state_saved():
			door_lid_manager.restore()

		await get_tree().create_timer(MODE_SWITCH_LOCK_TIME - CULL_MASK_DELAY).timeout
		if my_serial == operation_serial:
			is_resetting = false
			switching_to_index = -1


## 获取相机 cull_mask
func _get_camera_cull_mask() -> int:
	var cam: Camera3D = _get_camera()
	return cam.cull_mask if cam else 0


## 设置相机 cull_mask
func _set_camera_cull_mask(mask: int) -> void:
	var cam: Camera3D = _get_camera()
	if cam:
		cam.cull_mask = mask


## 获取相机节点
func _get_camera() -> Camera3D:
	var spring: Node = get_node_or_null("spring_arm")
	if spring:
		for child in spring.get_children():
			if child is Camera3D:
				return child
	return null


## 相机微调 Tween
var _camera_adjust_tween: Tween

var _zoom_soft_min: float = 3.0
var _zoom_soft_max: float = 30.0
var _transition_duration: float = 1.0
var _yaw_left_soft: float = 360.0
var _yaw_right_soft: float = 360.0
var _pitch_up_soft: float = 90.0
var _pitch_down_soft: float = 30.0


## 当前激活的相机数据表索引
var _current_camera_table_index: int = 0

## 旋转限制类型（RLT_NONE=0, RLT_HARD=1, RLT_SOFT=2）
var _yaw_limit_type: int = 0
var _pitch_limit_type: int = 0

## 不允许微调的视角索引：interior=3
const BLOCKED_ADJUST_INDICES: Array[int] = [3]

func _can_adjust_camera() -> bool:
	return _current_camera_table_index not in BLOCKED_ADJUST_INDICES

func _kill_camera_adjust_tween() -> void:
	if _camera_adjust_tween and _camera_adjust_tween.is_valid():
		_camera_adjust_tween.kill()


func _cache_camera_limits() -> void:
	var tables = get("camera_data_tables") as Array
	var table = tables[_current_camera_table_index] if tables and _current_camera_table_index >= 0 and _current_camera_table_index < tables.size() else null
	if table:
		_zoom_soft_min = table.get("length_soft_min") if table.get("length_soft_min") != null else 3.0
		_zoom_soft_max = table.get("length_soft_max") if table.get("length_soft_max") != null else 30.0
		_transition_duration = table.get("transition_duration") if table.get("transition_duration") != null else 1.0
		_yaw_left_soft = table.get("limit_yaw_left_soft") if table.get("limit_yaw_left_soft") != null else 360.0
		_yaw_right_soft = table.get("limit_yaw_right_soft") if table.get("limit_yaw_right_soft") != null else 360.0
		_pitch_up_soft = table.get("limit_pitch_up_soft") if table.get("limit_pitch_up_soft") != null else 90.0
		_pitch_down_soft = table.get("limit_pitch_down_soft") if table.get("limit_pitch_down_soft") != null else 30.0
		_yaw_limit_type = table.get("yaw_limit_type") if table.get("yaw_limit_type") != null else 0
		_pitch_limit_type = table.get("pitch_limit_type") if table.get("pitch_limit_type") != null else 0
	else:
		_yaw_limit_type = 0
		_pitch_limit_type = 0

## 镜头缩放（拉远/拉近）—— 直接 tween spring_arm.spring_length
## 格式: {percentage}:{direction}，direction: near/far
## near=拉近(缩短)，far=拉远(增长)
func adjust_camera_zoom(value: String) -> void:
	if not _can_adjust_camera():
		return

	var parts := value.split(":")
	var pct: float = parts[0].to_float()
	if pct <= 0.0:
		return
	var direction := "near" if parts.size() < 2 else parts[1]
	var factor := 1.0 / (1.0 + (pct / 100.0)) if direction == "near" else 1.0 + (pct / 100.0)

	var spring = get_node_or_null("spring_arm")
	if not spring:
		return
	var current_length: float = spring.get("spring_length")
	var target_length = clampf(current_length * factor, _zoom_soft_min, _zoom_soft_max)
	var _actual_delta_zoom := absf(target_length - current_length)
	var _duration_zoom := clampf(_actual_delta_zoom / 10.0, 0.2, 2.0)
	_kill_camera_adjust_tween()
	_camera_adjust_tween = create_tween()
	_camera_adjust_tween.tween_property(spring, "spring_length", target_length, _duration_zoom)
	_camera_adjust_tween.finished.connect(func(): _sync_elastic_to_current())


## 镜头环绕（左/右旋转）—— 直接 tween spring_arm.rotation_degrees:y
## 格式: {angle} 或 {angle}:{direction}，direction: left/right，默认left
func adjust_camera_orbit(value: String) -> void:
	if not _can_adjust_camera():
		return
	var parts := value.split(":")
	var angle: float = parts[0].to_float()
	if angle == 0.0 and parts[0] != "0":
		return
	var direction := "left" if parts.size() < 2 else parts[1]
	var delta := angle if direction == "right" else -angle
	var spring = get_node_or_null("spring_arm")
	if not spring:
		return
	var current_y: float = spring.get("rotation_degrees").y
	var target_y := current_y + delta
	if _yaw_limit_type != 0:
		target_y = clampf(target_y, -_yaw_left_soft, -_yaw_right_soft)
	var _actual_delta_y := absf(target_y - current_y)
	var _duration_y := clampf(_actual_delta_y / 60.0, 0.2, 2.0)
	_kill_camera_adjust_tween()
	_camera_adjust_tween = create_tween()
	_camera_adjust_tween.tween_property(spring, "rotation_degrees:y", target_y, _duration_y)
	_camera_adjust_tween.finished.connect(func(): _sync_elastic_to_current())


## 镜头俯仰（上/下倾斜）—— 直接 tween spring_arm.rotation_degrees:x
## 格式: {angle}:{direction}，direction: up/down
func adjust_camera_pitch(value: String) -> void:
	if not _can_adjust_camera():
		return
	var parts := value.split(":")
	var angle: float = parts[0].to_float()
	if angle == 0.0 and parts[0] != "0":
		return
	var direction := "up" if parts.size() < 2 else parts[1]
	var delta := angle if direction == "down" else -angle
	var spring = get_node_or_null("spring_arm")
	if not spring:
		return
	var current_x: float = spring.get("rotation_degrees").x
	var target_x := current_x + delta
	if _pitch_limit_type != 0:
		target_x = clampf(target_x, -_pitch_up_soft, -_pitch_down_soft)
	var _actual_delta_x := absf(target_x - current_x)
	var _duration_x := clampf(_actual_delta_x / 60.0, 0.2, 2.0)
	_kill_camera_adjust_tween()
	_camera_adjust_tween = create_tween()
	_camera_adjust_tween.tween_property(spring, "rotation_degrees:x", target_x, _duration_x)
	_camera_adjust_tween.finished.connect(func(): _sync_elastic_to_current())


## 根据模式更新主车碰撞形状的禁用状态
## LAUNCHER/VEHICLE_SETTINGS/CHARGING模式设为false（启用碰撞），其它模式设为true（禁用碰撞）
func _update_main_car_collision_disabled() -> void:
	var collision_enabled = (
		current_mode_index == CameraMode.LAUNCHER or
		current_mode_index == CameraMode.VEHICLE_SETTINGS or
		current_mode_index == CameraMode.CHARGING
	)
	for shape in main_car_collision_shapes:
		if shape:
			shape.disabled = not collision_enabled
	# 同步 C++ 端的交互许可
	if door_controller:
		door_controller.interaction_permitted = collision_enabled
