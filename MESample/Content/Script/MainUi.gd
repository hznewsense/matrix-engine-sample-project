## MainUi.gd
## 主界面控制器 - 管理顶部状态栏交互
class_name MainUi
extends Control

## 许可证信息按钮引用
@export var license_button: Button
@export var license_info: Control

## 温度控制按钮引用
@export var temp_decrease_button: Button  ## 温度减少按钮
@export var temp_increase_button: Button   ## 温度增加按钮
@export var temperature_label: Label       ## 温度显示标签
## 时间显示标签引用
@export var top_time_label: Label          ## 顶部状态栏时间标签
@export var main_time_label: Label         ## 主界面大时间标签

## 目标材质引用 (可选,用于直接更新材质)
@export var wind_material: Material

## 温度颜色设置
@export var cold_color := Color("#B0EFFF")  ## 最低温度时的颜色
@export var hot_color := Color("#D6A156")   ## 最高温度时的颜色

## 温度设置
const TEMP_MIN: int = 16  ## 最低温度
const TEMP_MAX: int = 30  ## 最高温度
const TEMP_STEP: int = 1  ## 温度调整步长

var current_temperature: int = 20  ## 当前温度，默认为20℃
var _last_time_text: String = ""   ## 缓存上次显示的时间文本


func _ready() -> void:
	_connect_signals()
	if license_info:
		license_info.visible = false
	# 非交互控件设为IGNORE，让鼠标事件穿透到3D场景
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top_bar = get_node_or_null("Topstatusbar")
	if top_bar: top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dock = get_node_or_null("Dock")
	if dock: dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	## 初始化温度显示
	_update_temperature_display()
	_update_material()
	## 初始化时间显示
	_update_time_display()
	## 创建定时器，每秒检查一次时间变化
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_update_time_display)
	add_child(timer)
	timer.start()


func _connect_signals() -> void:
	if license_button:
		license_button.pressed.connect(_on_license_button_pressed)
	if temp_decrease_button:
		temp_decrease_button.pressed.connect(_on_temp_decrease_pressed)
	if temp_increase_button:
		temp_increase_button.pressed.connect(_on_temp_increase_pressed)


## 许可证信息按钮点击回调 - 切换许可证信息显示/隐藏
func _on_license_button_pressed() -> void:
	if license_info:
		license_info.visible = not license_info.visible


## 温度减少按钮回调
func _on_temp_decrease_pressed() -> void:
	if current_temperature > TEMP_MIN:
		current_temperature -= TEMP_STEP
		_update_temperature_display()
		_update_material()


## 温度增加按钮回调
func _on_temp_increase_pressed() -> void:
	if current_temperature < TEMP_MAX:
		current_temperature += TEMP_STEP
		_update_temperature_display()
		_update_material()


## 更新温度显示
func _update_temperature_display() -> void:
	if temperature_label:
		temperature_label.text = str(current_temperature) + "°"


## 更新时间显示 - 获取系统时间(北京时间/UTC+8)
func _update_time_display() -> void:
	var time_dict: Dictionary = Time.get_time_dict_from_system()
	var time_text: String = "%02d : %02d" % [time_dict["hour"], time_dict["minute"]]
	if time_text == _last_time_text:
		return
	_last_time_text = time_text
	if top_time_label:
		top_time_label.text = time_text
	if main_time_label:
		main_time_label.text = time_text


## 根据当前温度更新材质参数
func _update_material() -> void:
	if wind_material:
		var ratio: float = float(current_temperature - TEMP_MIN) / float(TEMP_MAX - TEMP_MIN)
		var color := cold_color.lerp(hot_color, ratio)
		wind_material.set_shader_parameter("color", color)


## 获取当前温度
func get_temperature() -> int:
	return current_temperature


## 设置温度 (带边界检查)
func set_temperature(temp: int) -> void:
	current_temperature = clampi(temp, TEMP_MIN, TEMP_MAX)
	_update_temperature_display()
	_update_material()
