## NavMapController.gd
## 小地图控制器 - 使用Path2D映射3D路径
class_name NavMapController
extends Control

## 地图底图
@export var map_background: TextureRect

## 车辆图标
@export var vehicle_icon: TextureRect

## 2D路径节点
@export var path_2d: Path2D

## 2D路径跟随节点
@export var path_follow_2d: PathFollow2D

## 3D路径跟随节点（用于同步进度）
@export var path_follow_3d: PathFollow3D

## 地图内边距（像素）
@export var map_padding: float = 20.0

## 初始化是否完成
var _initialized: bool = false

func _ready() -> void:
	_initialize_later()

func _initialize_later() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_initialized = true

func _process(_delta: float) -> void:
	if not _initialized:
		return
	
	# 同步3D路径进度到2D路径
	_sync_progress()
	
	_update_vehicle_position()
	_update_vehicle_rotation()

## 同步PathFollow3D的进度到PathFollow2D
func _sync_progress() -> void:
	if path_follow_3d and path_follow_2d:
		path_follow_2d.progress_ratio = path_follow_3d.progress_ratio

## 更新车辆位置 - 直接使用PathFollow2D的位置
func _update_vehicle_position() -> void:
	if not vehicle_icon or not path_follow_2d:
		return
	
	vehicle_icon.position = path_follow_2d.position

## 更新车辆旋转 - 直接使用PathFollow2D的旋转
func _update_vehicle_rotation() -> void:
	if not vehicle_icon or not path_follow_2d:
		return
	
	# 顺时针旋转90度修正
	vehicle_icon.rotation = path_follow_2d.rotation + PI / 2

## 公开方法：获取当前路径进度
func get_progress() -> float:
	if path_follow_2d:
		return path_follow_2d.progress_ratio
	return 0.0
