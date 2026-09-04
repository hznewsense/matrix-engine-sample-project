## ModeUIManager.gd
## 模式UI管理器 - 负责按钮连接、UI可见性、遮罩纹理更新
class_name ModeUIManager
extends Node

## 相机模式枚举（与MainCameraController3D保持同步）
enum CameraMode {
	LAUNCHER = 0,
	VEHICLE_SETTINGS = 1,
	NAVIGATE = 2,
	INTERIOR = 3,
	APPLICATION = 4,
	CHARGING = 5,
	MUSIC = 6
}

## 按钮
@export_group("Button")
@export var btn_launcher: Button
@export var btn_vehicle_settings: Button
@export var btn_navigate: Button
@export var btn_interior: Button
@export var btn_application: Button
@export var btn_charging: Button
@export var btn_music: Button

@export_group("Mask")
@export var mask_material: Material
@export var mask_texture_launcher: Texture2D
@export var mask_texture_vehicle_settings: Texture2D
@export var mask_texture_navigate: Texture2D
@export var mask_texture_interior: Texture2D
@export var mask_texture_application: Texture2D
@export var mask_texture_charging: Texture2D
@export var mask_texture_music: Texture2D

## 各模式的UI
@export_group("Ui")
@export var ui_launcher: Control
@export var ui_vehicle_settings: Control
@export var ui_navigate: Control
@export var ui_interior: Control
@export var ui_application: Control
@export var ui_charging: Control
@export var ui_music: Control

## 信号：请求切换模式
signal mode_switch_requested(mode_index: int)

## 上一次进入Application前的模式（用于再次点击切回）
var _previous_mode_before_application: int = CameraMode.LAUNCHER
## 上一次进入Music前的模式（用于再次点击切回）
var _previous_mode_before_music: int = CameraMode.LAUNCHER

## 当前模式索引（由MainCameraController3D同步）
var current_mode_index: int = -1


func _ready() -> void:
	_connect_button_signals()


## 获取指定模式的UI节点
func _get_ui(mode_index: int) -> Control:
	match mode_index:
		CameraMode.LAUNCHER:
			return ui_launcher
		CameraMode.VEHICLE_SETTINGS:
			return ui_vehicle_settings
		CameraMode.NAVIGATE:
			return ui_navigate
		CameraMode.INTERIOR:
			return ui_interior
		CameraMode.APPLICATION:
			return ui_application
		CameraMode.CHARGING:
			return ui_charging
		CameraMode.MUSIC:
			return ui_music
	return null


## 获取指定模式的遮罩纹理
func _get_mask_texture(mode_index: int) -> Texture2D:
	match mode_index:
		CameraMode.LAUNCHER:
			return mask_texture_launcher
		CameraMode.VEHICLE_SETTINGS:
			return mask_texture_vehicle_settings
		CameraMode.NAVIGATE:
			return mask_texture_navigate
		CameraMode.INTERIOR:
			return mask_texture_interior
		CameraMode.APPLICATION:
			return mask_texture_application
		CameraMode.CHARGING:
			return mask_texture_charging
		CameraMode.MUSIC:
			return mask_texture_music
	return mask_texture_launcher


## 获取所有UI节点数组
func _get_all_uis() -> Array[Control]:
	var uis: Array[Control] = []
	uis.assign([ui_launcher, ui_vehicle_settings, ui_navigate, ui_interior, ui_application, ui_charging, ui_music])
	return uis


func _connect_button_signals() -> void:
	if btn_launcher:
		btn_launcher.pressed.connect(_on_button_launcher_pressed)
	if btn_vehicle_settings:
		btn_vehicle_settings.pressed.connect(_on_button_vehicle_settings_pressed)
	if btn_navigate:
		btn_navigate.pressed.connect(_on_button_navigate_pressed)
	if btn_interior:
		btn_interior.pressed.connect(_on_button_interior_pressed)
	if btn_application:
		btn_application.pressed.connect(_on_button_application_pressed)
	if btn_charging:
		btn_charging.pressed.connect(_on_button_charging_pressed)
	if btn_music:
		btn_music.pressed.connect(_on_button_music_pressed)


## 更新UI可见性
func update_ui_visibility(mode_index: int) -> void:
	# 隐藏所有UI
	for ui in _get_all_uis():
		if ui:
			ui.visible = false
	# 显示当前模式的UI
	var current_ui = _get_ui(mode_index)
	if current_ui:
		current_ui.visible = true


## 更新遮罩纹理
func update_mask_texture(mode_index: int) -> void:
	var texture = _get_mask_texture(mode_index)
	if mask_material and mask_material is ShaderMaterial:
		mask_material.set_shader_parameter("mask", texture)


## 按钮回调：Launcher
func _on_button_launcher_pressed() -> void:
	mode_switch_requested.emit(CameraMode.LAUNCHER)


## 按钮回调：VehicleSettings
func _on_button_vehicle_settings_pressed() -> void:
	mode_switch_requested.emit(CameraMode.VEHICLE_SETTINGS)


## 按钮回调：Navigate
func _on_button_navigate_pressed() -> void:
	mode_switch_requested.emit(CameraMode.NAVIGATE)


## 按钮回调：Interior
func _on_button_interior_pressed() -> void:
	mode_switch_requested.emit(CameraMode.INTERIOR)


## 按钮回调：Application
## 如果已在Application页面，再次点击切回上一次页面
## 如果进入Application前是Music，追溯到Music进入前的模式
func _on_button_application_pressed() -> void:
	if current_mode_index == CameraMode.APPLICATION:
		mode_switch_requested.emit(_previous_mode_before_application)
	else:
		if current_mode_index == CameraMode.MUSIC:
			_previous_mode_before_application = _previous_mode_before_music
		else:
			_previous_mode_before_application = current_mode_index
		mode_switch_requested.emit(CameraMode.APPLICATION)


## 按钮回调：Charging
func _on_button_charging_pressed() -> void:
	mode_switch_requested.emit(CameraMode.CHARGING)


## 按钮回调：Music
## 如果已在Music页面，再次点击切回上一次页面
## 如果进入Music前是Application，追溯到Application进入前的模式
func _on_button_music_pressed() -> void:
	if current_mode_index == CameraMode.MUSIC:
		mode_switch_requested.emit(_previous_mode_before_music)
	else:
		if current_mode_index == CameraMode.APPLICATION:
			_previous_mode_before_music = _previous_mode_before_application
		else:
			_previous_mode_before_music = current_mode_index
		mode_switch_requested.emit(CameraMode.MUSIC)
