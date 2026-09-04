extends Control

@onready var tab_container: TabContainer = $TabContainer
@onready var scale_3d_slider: HSlider = $TabContainer/Display/HBoxContainer/HSlider
@onready var scale_3d_label: Label = $TabContainer/Display/HBoxContainer/Label
@onready var bloom_check: CheckButton = $TabContainer/Performance/BloomCheck
@onready var fogs_check: CheckButton = $TabContainer/Performance/FogsCheck
@onready var reflection_check: CheckButton = $TabContainer/Performance/ReflectionCheck
@onready var carpaint_check: CheckButton = $TabContainer/Performance/CarpaintCheck

var click_count: int = 0

# Performance tab 目标节点(运行时查找, 缺失则禁用对应开关)
var _world_env: WorldEnvironment
var _fogs: Node3D
var _reflection_car: Node3D
var _door_lid_manager: Node

# 车漆反射: 收集主车所有含反射参数的 ShaderMaterial, 备份原值后整体切换
const REFLECTION_PARAMS: Array[String] = [
	"specularIntensity",
	"ExtraSpecularIntensity",
	"clearcoat_Intensity",
	"Flake_Intensity",
]
var _reflection_materials: Array[ShaderMaterial] = []
var _saved_reflection_values: Array[Dictionary] = []

func _ready() -> void:
	print("DebugUi ready")

	scale_3d_slider.min_value = 0.5
	scale_3d_slider.max_value = 1.25
	scale_3d_slider.step = 0.01
	scale_3d_slider.value = get_viewport().scaling_3d_scale
	_update_scale_3d_label(scale_3d_slider.value)

	_setup_performance()


func _setup_performance() -> void:
	# MainScene/MainUiCanvasLayer/DebugUi -> ../../3DLauncher, ../../ClusterViewport 等
	_world_env = get_node_or_null("../../3DLauncher/WorldEnvironment") as WorldEnvironment
	_fogs = get_node_or_null("../../3DLauncher/3dLauncher/Fogs") as Node3D
	_reflection_car = get_node_or_null("../../3DLauncher/3dLauncher/MatrixMainCar") as Node3D
	_door_lid_manager = get_node_or_null("../../Controller/DoorLidManager")

	if _world_env and _world_env.environment:
		bloom_check.set_pressed_no_signal(_world_env.environment.glow_enabled)
	else:
		bloom_check.disabled = true

	if _fogs:
		fogs_check.set_pressed_no_signal(_fogs.visible)
	else:
		fogs_check.disabled = true

	if _reflection_car:
		reflection_check.set_pressed_no_signal(_reflection_car.visible)
	else:
		reflection_check.disabled = true

	# 车漆反射: 递归遍历主车所有 mesh 收集 ShaderMaterial 反射参数
	var main_car := get_node_or_null("../../3DLauncher/MatrixMainCar") as Node3D
	if main_car:
		_collect_reflection_materials(main_car)
	if _reflection_materials.is_empty():
		carpaint_check.disabled = true

func _on_click_pressed() -> void:
	click_count += 1
	print("Click count: %d" % click_count)

	if click_count >= 3:
		tab_container.visible = !tab_container.visible
		click_count = 0

		if tab_container.visible:
			print("Debug UI 已展开")
		else:
			print("Debug UI 已收起")

# ----------------
# MSAA
# ----------------
func _on_disabled_button_pressed() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	print("MSAA: Disabled")

func _on_msaa_2x_button_pressed() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_2X
	print("MSAA: 2x")

func _on_msaa_4x_button_pressed() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	print("MSAA: 4x")

func _on_msaa_8x_button_pressed() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_8X
	print("MSAA: 8x")

# ----------------
# Resolution
# ----------------
func _on_1920x1200_pressed() -> void:
	_set_window_size(1920, 1200)

func _on_1600x900_pressed() -> void:
	_set_window_size(1600, 900)

func _on_1280x720_pressed() -> void:
	_set_window_size(1280, 720)

func _on_1024x768_pressed() -> void:
	_set_window_size(1024, 768)

func _set_window_size(width: int, height: int) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var new_size := Vector2i(width, height)
	DisplayServer.window_set_size(new_size)
	get_window().size = new_size
	get_tree().root.content_scale_size = new_size
	print("窗口大小: %dx%d" % [width, height])

# ----------------
# Scaling 3D
# ----------------
func _on_h_slider_value_changed(value: float) -> void:
	get_viewport().scaling_3d_scale = value
	_update_scale_3d_label(value)
	print("3D缩放: %.2f" % value)

func _update_scale_3d_label(value: float) -> void:
	var percent := int(round(value * 100.0))
	if is_equal_approx(value, 1.0):
		scale_3d_label.text = "3D分辨率: %d%%（原始）" % percent
	elif value < 1.0:
		scale_3d_label.text = "3D分辨率: %d%%（性能）" % percent
	else:
		scale_3d_label.text = "3D分辨率: %d%%（画质）" % percent

# ----------------
# Performance Tab
# ----------------
func _on_bloom_check_toggled(pressed: bool) -> void:
	if _world_env and _world_env.environment:
		_world_env.environment.glow_enabled = pressed
	print("Bloom 后处理: %s" % ("开启" if pressed else "关闭"))

func _on_fogs_check_toggled(pressed: bool) -> void:
	if _fogs:
		_fogs.visible = pressed
	print("雾粒子: %s" % ("开启" if pressed else "关闭"))

func _on_reflection_check_toggled(pressed: bool) -> void:
	if _reflection_car:
		_reflection_car.visible = pressed
	if _door_lid_manager:
		# 关闭倒影车时同步停掉每帧 transform 同步
		_door_lid_manager.set_process(pressed)
	print("倒影车模: %s" % ("开启" if pressed else "关闭"))

func _collect_reflection_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		_try_register_reflection_material(mi.material_override)
		var override_count := mi.get_surface_override_material_count()
		for i in range(override_count):
			_try_register_reflection_material(mi.get_surface_override_material(i))
		if mi.mesh:
			var surf_count := mi.mesh.get_surface_count()
			for i in range(surf_count):
				_try_register_reflection_material(mi.mesh.surface_get_material(i))
	for child in node.get_children():
		_collect_reflection_materials(child)

func _try_register_reflection_material(mat: Material) -> void:
	if not mat is ShaderMaterial:
		return
	var sm := mat as ShaderMaterial
	if sm in _reflection_materials:
		return
	var saved := {}
	for param in REFLECTION_PARAMS:
		var val = sm.get_shader_parameter(param)
		if val != null:
			saved[param] = val
	if saved.is_empty():
		return
	_reflection_materials.append(sm)
	_saved_reflection_values.append(saved)

func _on_carpaint_check_toggled(pressed: bool) -> void:
	for i in range(_reflection_materials.size()):
		var sm := _reflection_materials[i]
		var saved: Dictionary = _saved_reflection_values[i]
		for param in REFLECTION_PARAMS:
			if not saved.has(param):
				continue
			sm.set_shader_parameter(param, saved[param] if pressed else 0)
	var state := "开启" if pressed else "关闭"
	print("车漆反射: %s (%d 个材质)" % [state, _reflection_materials.size()])
