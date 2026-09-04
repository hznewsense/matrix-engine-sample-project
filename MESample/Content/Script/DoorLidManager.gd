## DoorLidManager.gd
## 四门三盖管理器 - 负责四门三盖动画的保存、恢复、关闭
## 同时负责倒影车模的全节点Transform同步
class_name DoorLidManager
extends Node

## 主车模根节点路径
@export var main_car_root: NodePath
## 倒影车模根节点路径
@export var reflection_car_root: NodePath

## 四门三盖节点
## 顺序建议：左前门、右前门、左后门、右后门、引擎盖、后备箱盖、充电口盖
@export var door_lid_nodes: Array[Node3D] = []

## 倒影车模的四门三盖节点（保留兼容，全节点同步模式下不再使用）
@export var reflection_door_lid_nodes: Array[Node3D] = []

## 四门三盖关闭状态Transform（_ready时记录，初始即关闭）
var _door_lid_closed_transforms: Array[Transform3D] = []
## Interior模式下保存的四门三盖原始Transform
var _saved_door_lid_transforms: Array[Transform3D] = []
## 是否已保存四门三盖状态（用于判断是否需要恢复）
var _door_lid_state_saved: bool = false
## 四门三盖动画Tween引用
var _door_lid_tween: Tween = null
## 四门三盖动画时长（秒）
const DOOR_LID_ANIM_DURATION: float = 1.0

## 预构建的全节点同步对（主车节点 -> 倒影车节点）
var _sync_main_nodes: Array[Node3D] = []
var _sync_ref_nodes: Array[Node3D] = []
## 根节点引用（spin动画旋转根节点，需额外同步rotation）
var _main_car: Node3D = null
var _ref_car: Node3D = null
## 根节点初始旋转（_ready时记录，用于计算旋转增量）
var _main_car_init_rotation: Vector3 = Vector3.ZERO
var _ref_car_init_rotation: Vector3 = Vector3.ZERO


func _ready() -> void:
	# 记录四门三盖的初始（关闭）Transform
	_save_door_lid_closed_transforms()

	# 预构建全节点同步对，避免每帧递归查找
	var main_car = get_node_or_null(main_car_root) as Node3D
	var ref_car = get_node_or_null(reflection_car_root) as Node3D
	if main_car and ref_car:
		_main_car = main_car
		_ref_car = ref_car
		_main_car_init_rotation = main_car.rotation
		_ref_car_init_rotation = ref_car.rotation
		_build_sync_pairs(main_car, ref_car)


func _process(_delta: float) -> void:
	# 同步根节点旋转（spin动画直接旋转根节点，子节点同步对不包含根节点）
	if _main_car and _ref_car:
		var delta = _main_car.rotation - _main_car_init_rotation
		_ref_car.rotation = _ref_car_init_rotation + delta
	# 全节点同步倒影车模Transform
	for i in range(_sync_main_nodes.size()):
		_sync_ref_nodes[i].transform = _sync_main_nodes[i].transform


## 递归构建同步节点对（按名称匹配主车和倒影车的Node3D子节点）
func _build_sync_pairs(main_node: Node3D, ref_node: Node3D) -> void:
	for child in main_node.get_children():
		if child is Node3D:
			var ref_child = ref_node.get_node_or_null(NodePath(child.name))
			if ref_child is Node3D:
				_sync_main_nodes.append(child)
				_sync_ref_nodes.append(ref_child)
				_build_sync_pairs(child, ref_child)


## 在_ready时记录四门三盖的关闭状态Transform（初始即关闭）
func _save_door_lid_closed_transforms() -> void:
	_door_lid_closed_transforms.clear()
	for node in door_lid_nodes:
		_door_lid_closed_transforms.append(node.transform if node else Transform3D.IDENTITY)


## 终止四门三盖动画
func _kill_door_lid_tween() -> void:
	if _door_lid_tween and _door_lid_tween.is_valid():
		_door_lid_tween.kill()
	_door_lid_tween = null


## 保存门盖的开启态 Transform
## 动画进行中（非稳态）时保留已保存的开启目标，避免被动画中间帧污染
## （快速切换 Launcher/Interior 时开启角度漂移的根因修复）
func _capture_open_transforms() -> void:
	if _door_lid_tween and _door_lid_tween.is_valid():
		return  # 动画进行中：门不在稳态，保留现有开启目标
	_saved_door_lid_transforms.clear()
	for i in range(door_lid_nodes.size()):
		if door_lid_nodes[i]:
			_saved_door_lid_transforms.append(door_lid_nodes[i].transform)
		else:
			_saved_door_lid_transforms.append(Transform3D.IDENTITY)


## 四门三盖动画：从当前状态平滑过渡到目标Transform
func _animate_door_lids(target_transforms: Array[Transform3D]) -> void:
	_kill_door_lid_tween()
	
	_door_lid_tween = create_tween().set_parallel(true)
	_door_lid_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	for i in range(door_lid_nodes.size()):
		if door_lid_nodes[i] and i < target_transforms.size():
			_door_lid_tween.tween_property(
				door_lid_nodes[i], "transform",
				target_transforms[i],
				DOOR_LID_ANIM_DURATION
			)
	
	_door_lid_tween.set_parallel(false)
	_door_lid_tween.finished.connect(_on_door_lid_anim_finished)


## 四门三盖瞬间关闭（无动画，直接设置到关闭状态）
## 用于SR→Interior切换时"假关"：保存当前状态但瞬间关闭，不播放动画
func apply_close_instant() -> void:
	if _door_lid_state_saved:
		return  # 已经保存过了，避免重复保存
	
	# 保存开启态：动画进行中则保留已保存的开启目标，避免被中间帧污染
	_capture_open_transforms()
	_door_lid_state_saved = true
	
	# 终止正在进行的动画
	_kill_door_lid_tween()
	
	# 瞬间设置到关闭状态（无动画）
	for i in range(door_lid_nodes.size()):
		if door_lid_nodes[i] and i < _door_lid_closed_transforms.size():
			door_lid_nodes[i].transform = _door_lid_closed_transforms[i]


## 四门三盖关闭动画（1s过渡到关闭状态）
func apply_close() -> void:
	if _door_lid_state_saved:
		return  # 已经保存过了，避免重复保存
	
	# 保存开启态：动画进行中则保留已保存的开启目标，避免被中间帧污染
	_capture_open_transforms()
	_door_lid_state_saved = true
	
	# 播放关闭动画
	_animate_door_lids(_door_lid_closed_transforms)


## 四门三盖开启动画（1s恢复到之前保存的状态）
func restore() -> void:
	if not _door_lid_state_saved:
		return  # 没有保存过，无需恢复
	
	_door_lid_state_saved = false  # 标记为恢复中，动画完成后清理
	# 播放开启动画
	_animate_door_lids(_saved_door_lid_transforms)


## 是否已保存门盖状态（用于判断是否需要恢复）
func is_state_saved() -> bool:
	return _door_lid_state_saved


## 四门三盖动画完成回调
func _on_door_lid_anim_finished() -> void:
	_door_lid_tween = null
