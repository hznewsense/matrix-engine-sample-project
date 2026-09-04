extends CameraController3D

## GearController 引用
@export var gear_controller: Node

## 车辆节点引用（用于D档跟随）
@export var matrix_main_car: Node3D

## 原点Transform（P/N/R档位置）
var camera_origin_transform: Transform3D

## 跟随偏移Transform
var camera_offset_transform: Transform3D

## 是否跟随车辆
var is_following_car: bool = false

## 仪表相机标记层：Cluster 相机 cull_mask 强制包含该层，shader 据此识别仪表相机渲染
const CLUSTER_CAM_MARK_LAYER: int = 16

## 缓存的相机节点引用（spring_arm 下的 Camera3D）
var _cluster_camera: Camera3D = null


func _ready() -> void:
	_connect_gear_signal()
	_save_origin_transform()
	_calculate_camera_offset()
	_cluster_camera = _get_camera()


## 每帧确保仪表相机 cull_mask 包含标记层（切换视角会覆盖 cull_mask，需持续强制）
func _process(_delta: float) -> void:
	if _cluster_camera == null:
		_cluster_camera = _get_camera()
	if _cluster_camera:
		_cluster_camera.cull_mask |= 1 << (CLUSTER_CAM_MARK_LAYER - 1)
	if is_following_car and matrix_main_car:
		_apply_camera_follow()


## 获取 spring_arm 下的相机节点
func _get_camera() -> Camera3D:
	var spring: Node = get_node_or_null("spring_arm")
	if spring:
		for child in spring.get_children():
			if child is Camera3D:
				return child
	return null


func _connect_gear_signal() -> void:
	if gear_controller:
		if gear_controller.has_signal("gear_changed"):
			gear_controller.gear_changed.connect(_on_gear_changed)


func _save_origin_transform() -> void:
	# 保存当前Transform作为原点
	camera_origin_transform = global_transform


func _calculate_camera_offset() -> void:
	# 参考VehicleDataController的计算方式
	if not matrix_main_car:
		return
	
	var camera_inv = matrix_main_car.global_transform.affine_inverse()
	camera_offset_transform = camera_inv * global_transform


func _apply_camera_follow() -> void:
	if not matrix_main_car:
		return

	var car_xform = matrix_main_car.global_transform
	var car_basis = car_xform.basis.orthonormalized()
	car_xform = Transform3D(car_basis, car_xform.origin)
	var target_transform = car_xform * camera_offset_transform
	global_transform = target_transform


func _apply_camera_origin() -> void:
	global_transform = camera_origin_transform


## 档位变化回调
func _on_gear_changed(_old_gear: int, new_gear: int) -> void:
	# P=0, D=1, N=2, R=3
	match new_gear:
		0:  # P
			is_following_car = false
			_apply_camera_origin()
			switch_by_index(0)
		1:  # D
			is_following_car = true
			_jump_camera_to_car()  # 立即跳转到车上
			switch_by_index(1)
		2:  # N
			is_following_car = false
			_apply_camera_origin()
			switch_by_index(2)
		3:  # R
			is_following_car = false
			_apply_camera_origin()
			switch_by_index(3)


func _jump_camera_to_car() -> void:
	_apply_camera_follow()
