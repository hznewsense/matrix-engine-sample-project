## GearController.gd
## 档位控制器 - 管理档位切换逻辑与车辆模拟状态
class_name GearController
extends Node

## 档位枚举
enum Gear {
	P = 0,  # 驻车档
	D = 1,  # 前进档
	N = 2,  # 空档
	R = 3,  # 倒车档
}

## 当前档位
var current_gear: Gear = Gear.P

## 目标车速 (km/h)
var target_speed: float

## VehicleDataController 引用
@export var vehicle_data_controller: Node

## 档位按钮引用
@export var gear_button: Button

## 档位图标资源
@export var icon_p: Texture2D
@export var icon_d: Texture2D
@export var icon_n: Texture2D
@export var icon_r: Texture2D

## 档位高亮颜色（顶部栏PNRD）
@export var highlight_color: Color = Color(0.824, 0.169, 0.169, 1.0)

## 档位默认颜色（顶部栏PNRD）
@export var default_color: Color = Color(1.0, 1.0, 1.0, 1.0)

## Cluster仪表盘高亮颜色
@export var cluster_highlight_color: Color = Color(1.0, 1.0, 1.0, 1.0)

## Cluster仪表盘默认颜色
@export var cluster_default_color: Color = Color(0.565, 0.565, 0.565, 1.0)

## PNRD Label 引用
@export var gear_label_p: Label
@export var gear_label_r: Label
@export var gear_label_n: Label
@export var gear_label_d: Label

## Cluster 仪表盘档位 Label 引用
@export var cluster_label_p: Label
@export var cluster_label_r: Label
@export var cluster_label_n: Label
@export var cluster_label_d: Label

## 档位切换顺序 (循环: P -> D -> N -> R -> P)
const GEAR_ORDER: Array[Gear] = [Gear.P, Gear.D, Gear.N, Gear.R]

## 信号：档位变化
signal gear_changed(old_gear: Gear, new_gear: Gear)


func _ready() -> void:
	_connect_button()
	# 初始状态：P档，模拟停止
	if vehicle_data_controller:
		vehicle_data_controller.pause_simulation()
	# 初始化档位Label高亮（默认P档）
	_update_gear_labels()


func _connect_button() -> void:
	if gear_button:
		gear_button.pressed.connect(_on_gear_button_pressed)


## 档位按钮点击回调 - 切换到下一个档位
func _on_gear_button_pressed() -> void:
	next_gear()


## 切换到下一个档位 (按顺序循环 P->D->N->R->P)
func next_gear() -> void:
	var current_index := GEAR_ORDER.find(current_gear)
	var next_index := (current_index + 1) % GEAR_ORDER.size()
	set_gear(GEAR_ORDER[next_index])


## 设置档位
func set_gear(new_gear: Gear) -> void:
	if current_gear == new_gear:
		return
	
	var old_gear := current_gear
	current_gear = new_gear
	
	# 处理档位切换逻辑
	_handle_gear_change(old_gear, new_gear)
	
	# 更新UI
	_update_gear_ui()
	
	# 发射信号
	gear_changed.emit(old_gear, new_gear)


## 处理档位切换逻辑
func _handle_gear_change(_old_gear: Gear, new_gear: Gear) -> void:
	if not vehicle_data_controller:
		return
	
	var vehicle_data = vehicle_data_controller.get_vehicle_data()
	if not vehicle_data:
		return
	
	match new_gear:
		Gear.D:
			# D档：恢复模拟，设置初始目标车速
			vehicle_data_controller.resume_simulation()
			# 重置速度计时器，让随机更新从头开始
			vehicle_data.call("reset_speed_timer")
			# 设置初始目标车速并重置外部控制模式
			vehicle_data.set_target_speed(60.0)  # 先设置一个初始值
			vehicle_data.call("reset_external_target_speed")  # 然后重置外部控制，让C++随机生成
		
		Gear.P, Gear.N, Gear.R:
			# P/N/R档：设置目标车速为0，车速降到0后模拟停止
			vehicle_data.set_target_speed(0.0)


## 更新档位UI显示
func _update_gear_ui() -> void:
	if gear_button:
		# 根据当前档位更新按钮图标
		match current_gear:
			Gear.P:
				gear_button.icon = icon_p
			Gear.D:
				gear_button.icon = icon_d
			Gear.N:
				gear_button.icon = icon_n
			Gear.R:
				gear_button.icon = icon_r
	
	# 更新PNRD Label颜色
	_update_gear_labels()


## 更新档位Label颜色高亮
func _update_gear_labels() -> void:
	# 先重置所有PNRD Label为默认颜色
	if gear_label_p:
		gear_label_p.add_theme_color_override("font_color", default_color)
	if gear_label_r:
		gear_label_r.add_theme_color_override("font_color", default_color)
	if gear_label_n:
		gear_label_n.add_theme_color_override("font_color", default_color)
	if gear_label_d:
		gear_label_d.add_theme_color_override("font_color", default_color)
	
	# 先重置所有Cluster Label为默认颜色
	if cluster_label_p:
		cluster_label_p.self_modulate = cluster_default_color
	if cluster_label_r:
		cluster_label_r.self_modulate = cluster_default_color
	if cluster_label_n:
		cluster_label_n.self_modulate = cluster_default_color
	if cluster_label_d:
		cluster_label_d.self_modulate = cluster_default_color
	
	# 根据当前档位高亮对应Label
	match current_gear:
		Gear.P:
			if gear_label_p:
				gear_label_p.add_theme_color_override("font_color", highlight_color)
			if cluster_label_p:
				cluster_label_p.self_modulate = cluster_highlight_color
		Gear.D:
			if gear_label_d:
				gear_label_d.add_theme_color_override("font_color", highlight_color)
			if cluster_label_d:
				cluster_label_d.self_modulate = cluster_highlight_color
		Gear.N:
			if gear_label_n:
				gear_label_n.add_theme_color_override("font_color", highlight_color)
			if cluster_label_n:
				cluster_label_n.self_modulate = cluster_highlight_color
		Gear.R:
			if gear_label_r:
				gear_label_r.add_theme_color_override("font_color", highlight_color)
			if cluster_label_r:
				cluster_label_r.self_modulate = cluster_highlight_color


## 设置目标车速
func set_target_speed_value(speed: float) -> void:
	target_speed = speed
	if current_gear == Gear.D and vehicle_data_controller:
		vehicle_data_controller.set_target_speed(target_speed)
