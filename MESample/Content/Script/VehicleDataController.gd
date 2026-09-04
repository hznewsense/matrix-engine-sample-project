## VehicleDataController.gd
## 车辆数据控制器 - 管理VehicleData模拟数据并驱动UI更新
class_name VehicleDataController
extends Node

## VehicleData实例
var vehicle_data: RefCounted

## 是否启用模拟
@export var simulation_enabled: bool = true

## 车速模拟参数
@export_group("Speed Simulation")
@export var random_speed_min: float = 0.0  # 随机目标车速最小值 (km/h)
@export var random_speed_max: float = 30.0  # 随机目标车速最大值 (km/h)
@export var accel_rate: float = 3.0         # 加速度 (km/h/s)
@export var decel_rate: float = 5.0         # 减速度 (km/h/s)
@export var speed_change_interval: float = 5.0  # 速度变化间隔 (秒)

## 轨迹事件模式
@export_group("Trajectory Mode")
@export var use_trajectory_mode: bool = true
@export var trajectory_events: Dictionary = {}  # 轨迹点事件配置

## UI引用 - 车速显示
@export var speed_label: Label
@export var speed_progress: Range

## UI引用 - NOA状态
@export var noa_status_label: Label
@export var noa_warning_label: Label
@export var noa_distance_label: Label
@export var noa_lane_change_indicator: Control

## UI引用 - SR NOA图标 (3种状态: off/on/warming)
@export var img_noa: TextureRect

## UI引用 - 红绿灯
@export var traffic_light_red: Control
@export var traffic_light_yellow: Control
@export var traffic_light_green: Control
@export var traffic_light_countdown_label: Label
@export var traffic_light_distance_label: Label

## UI引用 - SR信号灯图标
@export var img_signal_light: TextureRect
@export var txt_signal_countdown: Label

## UI引用 - 限速显示
@export var txt_current_speed: Label  # 最低限速/当前车速
@export var txt_limited_speed: Label  # 最高限速

## UI引用 - 导航TBT
@export var nav_instruction_label: Label
@export var nav_distance_label: Label
@export var nav_road_name_label: Label
@export var nav_direction_icon: TextureRect

## UI引用 - SR TBT卡片
@export var tbt_arrow: TextureRect
@export var tbt_miles: Label
@export var tbt_road: Label
@export var tbt_min: Label
@export var tbt_s: Label
@export var tbt_arrive_hour: Label
@export var tbt_arrive_minute: Label

## UI引用 - 道路箭头 (3个)
@export var img_road1: TextureRect
@export var img_road2: TextureRect
@export var img_road3: TextureRect

## 方向图标资源路径
@export var icon_straight: Texture2D
@export var icon_left: Texture2D
@export var icon_right: Texture2D
@export var icon_uturn: Texture2D

## NOA状态图标资源
@export var icon_noa_off: Texture2D
@export var icon_noa_on: Texture2D
@export var icon_noa_warming: Texture2D

## 3D场景节点引用
@export var curve_mover_3d: CurveMover3D
@export var matrix_main_car: Node3D

## 车轮节点引用
@export var wheel_fl: Node3D
@export var wheel_fr: Node3D
@export var wheel_rl: Node3D
@export var wheel_rr: Node3D
@export var wheel_radius: float = 0.35

## UI引用 - 仪表UI
@export_group("Cluster UI")
@export var cluster_speed_label: Label
@export var cluster_min_speed_label: Label
@export var cluster_max_speed_label: Label
@export var cluster_signal_light: TextureRect
@export var cluster_signal_countdown: Label

var wheel_rotation: float = 0.0

## 导航时间计时器
var nav_time_accumulator: float = 0.0

## NOA状态枚举
enum NOAStatus {
	INACTIVE = 0,
	ACTIVE = 1,
	UNAVAILABLE = 2,
}

## 红绿灯颜色枚举
enum TrafficLightColor {
	RED = 0,
	YELLOW = 1,
	GREEN = 2,
}

## 导航方向枚举
enum NavDirection {
	STRAIGHT = 0,
	LEFT = 1,
	RIGHT = 2,
	UTURN = 3,
}


func _ready() -> void:
	# 设置物理帧优先级，确保在 CurveMover3D 之后执行
	process_priority = 10
	
	# 创建VehicleData实例 (C++注册类)
	if ClassDB.class_exists("VehicleData"):
		vehicle_data = ClassDB.instantiate("VehicleData")
		
		# 设置车速模拟参数
		vehicle_data.set("speed_random_min", random_speed_min)
		vehicle_data.set("speed_random_max", random_speed_max)
		vehicle_data.set("speed_accel_rate", accel_rate)
		vehicle_data.set("speed_decel_rate", decel_rate)
		vehicle_data.set("speed_change_interval", speed_change_interval)
		
		# 设置轨迹事件模式
		vehicle_data.set("trajectory_use_mode", use_trajectory_mode)
		vehicle_data.set("trajectory_events", trajectory_events)
		
		# 连接信号
		vehicle_data.speed_changed.connect(_on_speed_changed)
		vehicle_data.noa_status_changed.connect(_on_noa_status_changed)
		vehicle_data.traffic_light_changed.connect(_on_traffic_light_changed)
		vehicle_data.navigation_changed.connect(_on_navigation_changed)
		
		# 连接新增信号
		if vehicle_data.has_signal("speed_limit_changed"):
			vehicle_data.speed_limit_changed.connect(_on_speed_limit_changed)
		if vehicle_data.has_signal("road_arrows_changed"):
			vehicle_data.road_arrows_changed.connect(_on_road_arrows_changed)
		if vehicle_data.has_signal("tbt_changed"):
			vehicle_data.tbt_changed.connect(_on_tbt_changed)
		if vehicle_data.has_signal("nav_time_changed"):
			vehicle_data.nav_time_changed.connect(_on_nav_time_changed)
		
		# 初始化UI
		_update_all_ui()
		
		# 初始化 curve_mover_3d
		if curve_mover_3d:
			curve_mover_3d.driving_speed = 0.0
			if curve_mover_3d.has_signal("point_passed"):
				curve_mover_3d.point_passed.connect(_on_curve_mover_point_passed)
	else:
		push_error("VehicleData class not found. Make sure MESample GDExtension is loaded.")



func _physics_process(delta: float) -> void:
	if not simulation_enabled:
		return
	
	if vehicle_data and vehicle_data.has_method("update_simulation"):
		vehicle_data.update_simulation(delta)
	
	_update_car_follow()
	_update_wheel_rotation(delta)
	
	# 更新导航时间（每秒）
	if use_trajectory_mode:
		nav_time_accumulator += delta
		if nav_time_accumulator >= 1.0:
			nav_time_accumulator = 0.0
			if vehicle_data and vehicle_data.has_method("update_nav_time"):
				vehicle_data.update_nav_time()


## 轨迹点通过回调
func _on_curve_mover_point_passed(point_index: int) -> void:
	if vehicle_data and vehicle_data.has_method("on_trajectory_point_passed"):
		vehicle_data.on_trajectory_point_passed(point_index)


func _update_wheel_rotation(delta: float) -> void:
	if not vehicle_data:
		return
	
	var speed_kmh = vehicle_data.get_current_speed()
	var speed_ms = speed_kmh / 3.6
	var rotation_angle = speed_ms * delta / wheel_radius
	
	wheel_rotation += rotation_angle
	
	if wheel_fl:
		wheel_fl.rotation.x = wheel_rotation
	if wheel_fr:
		wheel_fr.rotation.x = wheel_rotation
	if wheel_rl:
		wheel_rl.rotation.x = wheel_rotation
	if wheel_rr:
		wheel_rr.rotation.x = wheel_rotation


func _update_car_follow() -> void:
	if not curve_mover_3d or not matrix_main_car:
		return
	
	var path_follow = curve_mover_3d.get_node_or_null("PathFollow3D")
	if not path_follow:
		return
	
	# 根据车速设置 CurveMover3D 的 driving_speed
	if vehicle_data:
		var speed_kmh = vehicle_data.get_current_speed()
		curve_mover_3d.driving_speed = speed_kmh * 1.5

	var car_transform = path_follow.global_transform
	var rotation_correction = Transform3D.IDENTITY.rotated(Vector3.UP, PI)
	var target = car_transform * rotation_correction
	# Save scale, apply PathFollow position+rotation, then restore scale
	var current_scale = matrix_main_car.scale
	matrix_main_car.global_transform = target
	matrix_main_car.scale = current_scale


## 更新所有UI
func _update_all_ui() -> void:
	if not vehicle_data:
		return
	
	_on_speed_changed(vehicle_data.get_current_speed())
	_on_noa_status_changed(vehicle_data.get_noa_status(), vehicle_data.get_noa_warning())
	_on_traffic_light_changed(vehicle_data.get_traffic_light())
	_on_navigation_changed(vehicle_data.get_navigation_instructions())
	
	# 更新增的UI
	if vehicle_data.has_method("get_current_speed_limit"):
		_on_speed_limit_changed(vehicle_data.get_current_speed_limit(), vehicle_data.get_current_min_speed())
	if vehicle_data.has_method("get_road_arrows"):
		_on_road_arrows_changed(vehicle_data.get_road_arrows())
	if vehicle_data.has_method("get_tbt_road_name"):
		_on_tbt_changed(vehicle_data.get_tbt_road_name(), vehicle_data.get_tbt_distance(), vehicle_data.get_tbt_direction())
	if vehicle_data.has_method("get_nav_remaining_minutes"):
		_on_nav_time_changed(vehicle_data.get_nav_remaining_minutes(), vehicle_data.get_nav_remaining_seconds(), 
			vehicle_data.get_nav_arrive_hour(), vehicle_data.get_nav_arrive_minute())
	
	# 更新仪表红绿灯
	if vehicle_data.has_method("get_traffic_light"):
		var light_data = vehicle_data.get_traffic_light()
		_update_signal_light(light_data.get("color", TrafficLightColor.RED), light_data.get("countdown", 0.0))


## 车速变化回调
func _on_speed_changed(speed: float) -> void:
	# 更新车速显示
	if speed_label:
		speed_label.text = "%d" % int(speed)
	
	if speed_progress:
		speed_progress.value = speed
	
	# 更新仪表车速显示
	if cluster_speed_label:
		cluster_speed_label.text = "%d" % int(speed)
	
	# 当车速为0时，检查是否需要停止模拟
	if speed <= 0.0 and vehicle_data:
		var target_speed = vehicle_data.get_target_speed() if vehicle_data.has_method("get_target_speed") else 0.0
		if target_speed <= 0.0:
			# 目标车速为0且当前车速为0，停止模拟
			pause_simulation()
	
	# 发射自定义信号供外部使用
	speed_updated.emit(speed)


## NOA状态变化回调
func _on_noa_status_changed(status: int, warning: String) -> void:
	# 更新NOA状态显示
	if noa_status_label:
		match status:
			NOAStatus.INACTIVE:
				noa_status_label.text = "NOA 未激活"
				noa_status_label.modulate = Color.GRAY
			NOAStatus.ACTIVE:
				noa_status_label.text = "NOA 激活中"
				noa_status_label.modulate = Color.GREEN
			NOAStatus.UNAVAILABLE:
				noa_status_label.text = "NOA 不可用"
				noa_status_label.modulate = Color.RED
	
	if noa_warning_label:
		noa_warning_label.text = warning
		noa_warning_label.visible = not warning.is_empty()
	
	if noa_distance_label and vehicle_data:
		var distance = vehicle_data.get_noa_remaining_distance()
		if distance > 1000:
			noa_distance_label.text = "%.1f km" % (distance / 1000.0)
		else:
			noa_distance_label.text = "%.0f m" % distance
	
	if noa_lane_change_indicator and vehicle_data:
		noa_lane_change_indicator.visible = vehicle_data.is_noa_lane_change_pending()
	
	# 更新SR NOA图标
	_update_noa_icon(status)
	
	noa_status_updated.emit(status, warning)


## 更新NOA图标
func _update_noa_icon(status: int) -> void:
	if not img_noa:
		return
	
	match status:
		NOAStatus.INACTIVE:
			if icon_noa_off:
				img_noa.texture = icon_noa_off
		NOAStatus.ACTIVE:
			if icon_noa_on:
				img_noa.texture = icon_noa_on
		NOAStatus.UNAVAILABLE:
			if icon_noa_warming:
				img_noa.texture = icon_noa_warming


## 红绿灯变化回调
func _on_traffic_light_changed(light_data: Dictionary) -> void:
	var color = light_data.get("color", TrafficLightColor.RED)
	var countdown = light_data.get("countdown", 0.0)
	var distance = light_data.get("distance", 0.0)
	
	# 更新红绿灯颜色指示
	if traffic_light_red:
		traffic_light_red.modulate.a = 1.0 if color == TrafficLightColor.RED else 0.3
	if traffic_light_yellow:
		traffic_light_yellow.modulate.a = 1.0 if color == TrafficLightColor.YELLOW else 0.3
	if traffic_light_green:
		traffic_light_green.modulate.a = 1.0 if color == TrafficLightColor.GREEN else 0.3
	
	# 更新倒计时
	if traffic_light_countdown_label:
		traffic_light_countdown_label.text = "%d" % int(ceil(countdown))
	
	# 更新距离
	if traffic_light_distance_label:
		traffic_light_distance_label.text = "%.0f m" % distance
	
	# 更新SR红绿灯图标
	_update_signal_light(color, countdown)
	
	traffic_light_updated.emit(light_data)


## 更新SR红绿灯图标
func _update_signal_light(color: int, countdown: float) -> void:
	if img_signal_light:
		match color:
			TrafficLightColor.RED:
				img_signal_light.self_modulate = Color(0.78, 0.17, 0.19)  # 红色
			TrafficLightColor.YELLOW:
				img_signal_light.self_modulate = Color(0.9, 0.8, 0.1)  # 黄色
			TrafficLightColor.GREEN:
				img_signal_light.self_modulate = Color(0.2, 0.8, 0.2)  # 绿色
	
	if txt_signal_countdown:
		txt_signal_countdown.text = "%d" % int(ceil(countdown))
	
	# 更新仪表红绿灯
	if cluster_signal_light:
		match color:
			TrafficLightColor.RED:
				cluster_signal_light.self_modulate = Color(0.78, 0.17, 0.19)  # 红色
			TrafficLightColor.YELLOW:
				cluster_signal_light.self_modulate = Color(0.9, 0.8, 0.1)  # 黄色
			TrafficLightColor.GREEN:
				cluster_signal_light.self_modulate = Color(0.2, 0.8, 0.2)  # 绿色
	
	if cluster_signal_countdown:
		cluster_signal_countdown.text = "%d" % int(ceil(countdown))


## 导航变化回调
func _on_navigation_changed(instructions: Array) -> void:
	if not vehicle_data:
		return
	
	var current_nav = vehicle_data.get_current_navigation()
	if current_nav.is_empty():
		return
	
	# 更新导航指示
	if nav_instruction_label:
		nav_instruction_label.text = current_nav.get("instruction", "")
	
	if nav_distance_label:
		var distance = current_nav.get("distance", 0.0)
		if distance > 1000:
			nav_distance_label.text = "%.1f km" % (distance / 1000.0)
		else:
			nav_distance_label.text = "%.0f m" % distance
	
	if nav_road_name_label:
		nav_road_name_label.text = current_nav.get("road_name", "")
	
	# 更新方向图标
	if nav_direction_icon:
		var direction = current_nav.get("direction", NavDirection.STRAIGHT)
		match direction:
			NavDirection.STRAIGHT:
				nav_direction_icon.texture = icon_straight
			NavDirection.LEFT:
				nav_direction_icon.texture = icon_left
			NavDirection.RIGHT:
				nav_direction_icon.texture = icon_right
			NavDirection.UTURN:
				nav_direction_icon.texture = icon_uturn
	
	navigation_updated.emit(instructions)


## 限速变化回调
func _on_speed_limit_changed(limit: int, min_speed: int) -> void:
	# 更新最高限速显示
	if txt_limited_speed:
		txt_limited_speed.text = "%d" % limit
	
	# 更新最低限速/当前车速显示
	if txt_current_speed:
		txt_current_speed.text = "%d" % min_speed
	
	# 更新仪表限速显示
	if cluster_max_speed_label:
		cluster_max_speed_label.text = "%d" % limit
	if cluster_min_speed_label:
		cluster_min_speed_label.text = "%d" % min_speed
	
	speed_limit_updated.emit(limit, min_speed)


## 道路箭头变化回调
func _on_road_arrows_changed(arrows: Array) -> void:
	# 更新3个道路箭头
	if arrows.size() >= 1 and img_road1:
		_update_road_arrow(img_road1, arrows[0])
	if arrows.size() >= 2 and img_road2:
		_update_road_arrow(img_road2, arrows[1])
	if arrows.size() >= 3 and img_road3:
		_update_road_arrow(img_road3, arrows[2])
	
	road_arrows_updated.emit(arrows)


## 更新单个道路箭头图标
func _update_road_arrow(arrow: TextureRect, direction: int) -> void:
	match direction:
		NavDirection.STRAIGHT:
			if icon_straight:
				arrow.texture = icon_straight
		NavDirection.LEFT:
			if icon_left:
				arrow.texture = icon_left
		NavDirection.RIGHT:
			if icon_right:
				arrow.texture = icon_right
		NavDirection.UTURN:
			if icon_uturn:
				arrow.texture = icon_uturn


## TBT导航变化回调
func _on_tbt_changed(road_name: String, distance: int, direction: int) -> void:
	# 更新TBT卡片
	if tbt_road:
		tbt_road.text = road_name
	
	# TBT距离只显示米数(0-999m)
	if tbt_miles:
		var display_distance = distance
		if display_distance > 999:
			display_distance = 999
		tbt_miles.text = "%d" % display_distance
	
	if tbt_arrow:
		match direction:
			NavDirection.STRAIGHT:
				if icon_straight:
					tbt_arrow.texture = icon_straight
			NavDirection.LEFT:
				if icon_left:
					tbt_arrow.texture = icon_left
			NavDirection.RIGHT:
				if icon_right:
					tbt_arrow.texture = icon_right
			NavDirection.UTURN:
				if icon_uturn:
					tbt_arrow.texture = icon_uturn
	
	tbt_updated.emit(road_name, distance, direction)


## 导航时间变化回调
func _on_nav_time_changed(minutes: int, seconds: int, arrive_hour: int, arrive_minute: int) -> void:
	if tbt_min:
		tbt_min.text = "%d" % minutes
	if tbt_s:
		tbt_s.text = "%02d" % seconds
	if tbt_arrive_hour:
		tbt_arrive_hour.text = "%02d" % arrive_hour
	if tbt_arrive_minute:
		tbt_arrive_minute.text = "%02d" % arrive_minute
	
	nav_time_updated.emit(minutes, seconds, arrive_hour, arrive_minute)


## 公开方法：设置轨迹事件配置
func set_trajectory_events(events: Dictionary) -> void:
	trajectory_events = events
	if vehicle_data and vehicle_data.has_method("set_trajectory_events"):
		vehicle_data.set("trajectory_events", events)


## 公开方法：重置模拟
func reset_simulation() -> void:
	if vehicle_data and vehicle_data.has_method("reset"):
		vehicle_data.reset()
		_update_all_ui()


## 公开方法：暂停模拟
func pause_simulation() -> void:
	if vehicle_data and vehicle_data.has_method("pause"):
		vehicle_data.pause()
	simulation_enabled = false


## 公开方法：恢复模拟
func resume_simulation() -> void:
	if vehicle_data and vehicle_data.has_method("resume"):
		vehicle_data.resume()
	simulation_enabled = true


## 公开方法：设置目标车速
func set_target_speed(speed: float) -> void:
	if vehicle_data:
		vehicle_data.set_target_speed(speed)


## 公开方法：获取当前车速
func get_current_speed() -> float:
	if vehicle_data:
		return vehicle_data.get_current_speed()
	return 0.0


## 公开方法：获取VehicleData实例
func get_vehicle_data() -> RefCounted:
	return vehicle_data


## 信号定义
signal speed_updated(speed: float)
signal noa_status_updated(status: int, warning: String)
signal traffic_light_updated(light_data: Dictionary)
signal navigation_updated(instructions: Array)
signal speed_limit_updated(limit: int, min_speed: int)
signal road_arrows_updated(arrows: Array)
signal tbt_updated(road_name: String, distance: int, direction: int)
signal nav_time_updated(minutes: int, seconds: int, arrive_hour: int, arrive_minute: int)
